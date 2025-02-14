import { PythonFunction, PythonFunctionProps } from '@aws-cdk/aws-lambda-python-alpha';
import {
  aws_apigateway,
  aws_apigateway as apigw,
  aws_dynamodb,
  aws_iam,
  aws_lambda,
  Duration,
} from 'aws-cdk-lib';
import { MethodOptions } from 'aws-cdk-lib/aws-apigateway/lib/method';
import { Effect } from 'aws-cdk-lib/aws-iam';
import { Architecture, Runtime } from 'aws-cdk-lib/aws-lambda';
import { Construct } from 'constructs';


export interface ListAllModelJobApiProps {
  router: aws_apigateway.Resource;
  httpMethod: string;
  modelTable: aws_dynamodb.Table;
  multiUserTable: aws_dynamodb.Table;
  srcRoot: string;
  commonLayer: aws_lambda.LayerVersion;
  authorizer: aws_apigateway.IAuthorizer;
}

export class ListAllModelJobApi {
  private readonly src;
  private readonly router: aws_apigateway.Resource;
  private readonly httpMethod: string;
  private readonly scope: Construct;
  private readonly modelTable: aws_dynamodb.Table;
  private readonly multiUserTable: aws_dynamodb.Table;
  private readonly layer: aws_lambda.LayerVersion;
  private readonly authorizer: aws_apigateway.IAuthorizer;

  private readonly baseId: string;

  constructor(scope: Construct, id: string, props: ListAllModelJobApiProps) {
    this.scope = scope;
    this.baseId = id;
    this.router = props.router;
    this.httpMethod = props.httpMethod;
    this.modelTable = props.modelTable;
    this.multiUserTable = props.multiUserTable;
    this.src = props.srcRoot;
    this.layer = props.commonLayer;
    this.authorizer = props.authorizer;

    this.listAllModelJobApi();
  }

  private iamRole(): aws_iam.Role {
    const newRole = new aws_iam.Role(this.scope, `${this.baseId}-role`, {
      assumedBy: new aws_iam.ServicePrincipal('lambda.amazonaws.com'),
    });
    newRole.addToPolicy(new aws_iam.PolicyStatement({
      effect: Effect.ALLOW,
      actions: [
        'dynamodb:BatchGetItem',
        'dynamodb:GetItem',
        'dynamodb:Scan',
        'dynamodb:Query',
      ],
      resources: [
        this.modelTable.tableArn,
        this.multiUserTable.tableArn,
      ],
    }));

    newRole.addToPolicy(new aws_iam.PolicyStatement({
      effect: Effect.ALLOW,
      actions: [
        'logs:CreateLogGroup',
        'logs:CreateLogStream',
        'logs:PutLogEvents',
        'kms:Decrypt',
      ],
      resources: ['*'],
    }));
    return newRole;
  }

  private listAllModelJobApi() {
    const lambdaFunction = new PythonFunction(this.scope, `${this.baseId}-listall`, <PythonFunctionProps>{
      functionName: `${this.baseId}-listall-models`,
      entry: `${this.src}/model_and_train`,
      architecture: Architecture.X86_64,
      runtime: Runtime.PYTHON_3_9,
      index: 'model_api.py',
      handler: 'list_all_models_api',
      timeout: Duration.seconds(900),
      role: this.iamRole(),
      memorySize: 1024,
      environment: {
        DYNAMODB_TABLE: this.modelTable.tableName,
        MULTI_USER_TABLE: this.multiUserTable.tableName,
      },
      layers: [this.layer],
    });
    const createModelIntegration = new apigw.LambdaIntegration(
      lambdaFunction,
      {
        proxy: false,
        requestParameters: {
          'integration.request.querystring.status': 'method.request.querystring.status',
          'integration.request.querystring.types': 'method.request.querystring.types',
        },
        requestTemplates: {
          'application/json': '{\n' +
              '    "queryStringParameters": {\n' +
              '      #foreach($key in $method.request.multivaluequerystring.keySet())\n' +
              '      "$key" : [\n' +
              '        #foreach($val in $method.request.multivaluequerystring.get($key))\n' +
              '       "$val"#if($foreach.hasNext),#end\n' +
              '        #end\n' +
              '        ]#if($foreach.hasNext),#end\n' +
              '      #end\n' +
              '    },\n' +
              '    "x-auth": {\n' +
              '        "username": "$context.authorizer.username",\n' +
              '        "role": "$context.authorizer.role"\n' +
              '    }\n' +
              '}',
        },
        integrationResponses: [{ statusCode: '200' }],
      },
    );
    this.router.addMethod(this.httpMethod, createModelIntegration, <MethodOptions>{
      apiKeyRequired: true,
      authorizer: this.authorizer,
      requestParameters: {
        'method.request.querystring.status': true,
        'method.request.querystring.types': true,
      },
      methodResponses: [{
        statusCode: '200',
      }],
    });
  }
}

