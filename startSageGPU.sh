#!/bin/bash
set -e # 在脚本执行过程中，如果任何语句的执行结果非真（返回非零状态），那么整个脚本就会立即终止执行
# exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1 # 需要 root 权限

SD_HOME=/home/ec2-user/SageMaker/genai
mkdir -p $SD_HOME
cd /home/ec2-user/SageMaker/genai

echo -e "Prepare runtime ..." # -e 选项用于启用转义字符的解析
# sudo yum update -y
sudo yum install -y yum-utils && sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo && \
  sudo yum install -y wget git net-tools libgl1 needrestart python3-pip && \
  pip install httpx==0.22.0 && pip install httpcore==0.14.7

echo -e "Get stable-diffusion-webui ..."
git clone https://github.com/TipTopBin/stable-diffusion-webui $SD_HOME/sd-webui

echo -e "Setup aws related extensions ..." # sync version
git clone https://github.com/TipTopBin/stable-diffusion-aws-extension.git $SD_HOME/sd-webui/extensions/stable-diffusion-aws-extension
cd $SD_HOME/sd-webui/extensions/stable-diffusion-aws-extension && ./r_pre-flight.sh -f

echo -e "Get more extensions..."
git clone https://github.com/TipTopBin/sd-webui-bilingual-localization $SD_HOME/sd-webui/extensions/sd-webui-bilingual-localization && \
  git clone https://github.com/TipTopBin/stable-diffusion-webui-localization-zh_Hans $SD_HOME/sd-webui/extensions/stable-diffusion-webui-localization-zh_Hans && \
  git clone https://github.com/TipTopBin/sd-webui-prompt-all-in-one $SD_HOME/sd-webui/extensions/sd-webui-prompt-all-in-one && \
  git clone https://github.com/TipTopBin/stable-diffusion-webui-images-browser $SD_HOME/sd-webui/extensions/stable-diffusion-webui-images-browser

echo -e "Download models ..."
mkdir -p $SD_HOME/sd-webui/models/Lora
wget -O $SD_HOME/sd-webui/models/Stable-diffusion/sd_xl_base_1.0.safetensors https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/resolve/main/sd_xl_base_1.0.safetensors             
# wget https://aws-gcr-solutions.s3.amazonaws.com/stable-diffusion-aws-extension-github-mainline/models/nendoroid_xl_v7.safetensors
#wget https://aws-gcr-solutions.s3.amazonaws.com/stable-diffusion-aws-extension-github-mainline/models/LahCuteCartoonSDXL_alpha.safetensors

sudo chown -R ec2-user:ec2-user $SD_HOME/

echo -e "Start sd service ..."
SD_PWD=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 17 ; echo '')
echo "export SD_HOME=\"$SD_HOME\"" >> ~/SageMaker/custom/bashrc
echo "export SD_PWD=\"$SD_PWD\"" >> ~/SageMaker/custom/bashrc
source ~/.bashrc
cd $SD_HOME/sd-webui # WorkingDirectory 注意一定要进入到这个目录 
nohup $SD_HOME/sd-webui/webui.sh --gradio-auth admin:${SD_PWD} --cors-allow-origins=* --enable-insecure-extension-access --allow-code --medvram --xformers --listen --port 8760 > $SD_HOME/sd.log 2>&1 & # execute asynchronously
# cd ~/SageMaker/awesome/do/sd-aws-extension/stable-diffusion-webui
# ./webui.sh --enable-insecure-extension-access --port 8760 --allow-code --medvram --xformers --subpath proxy/8760/ --listen
