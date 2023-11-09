#!/bin/bash
set -e # 在脚本执行过程中，如果任何语句的执行结果非真（返回非零状态），那么整个脚本就会立即终止执行
# exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1 # 需要 root 权限

sudo apt-get update
sudo apt install software-properties-common -y
sudo add-apt-repository ppa:deadsnakes/ppa -y
sudo apt install wget git build-essential net-tools libgl1 needrestart -y # python3 python3.8-venv python3.10 python3.10-venv
sudo sed -i "/#\$nrconf{restart} = 'i';/s/.*/\$nrconf{restart} = 'a';/" /etc/needrestart/needrestart.conf
# sudo -u ubuntu python3 -m venv venv
# source venv/bin/activate
# pip install httpx==0.22.0 # 0.24.1
# pip install httpcore==0.14.7

WORK_HOME=/home/ubuntu/environment
mkdir -p ${WORK_HOME}
cd ${WORK_HOME}
sudo mount -a
sudo chown -R ubuntu:ubuntu ${WORK_HOME}/*

echo -e "Clone AUTOMATIC1111 WebUI and set to supported version ..." # -e 选项用于启用转义字符的解析
# git clone https://github.com/AUTOMATIC1111/stable-diffusion-webui.git
git clone https://github.com/TipTopBin/stable-diffusion-webui $WORK_HOME/stable-diffusion-webui

echo -e "Add aws related extensions..."
git clone https://github.com/TipTopBin/stable-diffusion-aws-extension.git $WORK_HOME/stable-diffusion-webui/extensions/stable-diffusion-aws-extension

cd $WORK_HOME/stable-diffusion-webui/extensions/stable-diffusion-aws-extension
./r_pre-flight.sh -f # sync version

echo -e "Get more extensions..."
git clone https://github.com/TipTopBin/sd-webui-bilingual-localization $WORK_HOME/stable-diffusion-webui/extensions/sd-webui-bilingual-localization
git clone https://github.com/TipTopBin/stable-diffusion-webui-localization-zh_Hans $WORK_HOME/stable-diffusion-webui/extensions/stable-diffusion-webui-localization-zh_Hans
git clone https://github.com/TipTopBin/sd-webui-prompt-all-in-one $WORK_HOME/stable-diffusion-webui/extensions/sd-webui-prompt-all-in-one
git clone https://github.com/TipTopBin/stable-diffusion-webui-images-browser $WORK_HOME/stable-diffusion-webui/extensions/stable-diffusion-webui-images-browser

sudo chown -R ubuntu:ubuntu ${WORK_HOME}/*

echo -e "Download models ..."
wget -P ${WORK_HOME}/stable-diffusion-webui/models/Stable-diffusion https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/resolve/main/sd_xl_base_1.0.safetensors
#wget https://aws-gcr-solutions.s3.amazonaws.com/stable-diffusion-aws-extension-github-mainline/models/LahCuteCartoonSDXL_alpha.safetensors
wget -P ${WORK_HOME}/stable-diffusion-webui/models/ControlNet https://huggingface.co/lllyasviel/ControlNet-v1-1/resolve/main/control_v11p_sd15_canny.pth
wget -P ${WORK_HOME}/stable-diffusion-webui/models/ControlNet https://huggingface.co/lllyasviel/ControlNet-v1-1/resolve/main/control_v11p_sd15_openpose.pth


sudo mkdir $WORK_HOME/stable-diffusion-webui/models/Lora
sudo chown -R ubuntu:ubuntu $WORK_HOME/stable-diffusion-webui/models/Lora           
wget -P ${WORK_HOME}/stable-diffusion-webui/models/Lora https://aws-gcr-solutions.s3.amazonaws.com/stable-diffusion-aws-extension-github-mainline/models/nendoroid_xl_v7.safetensors

echo -e "Configue sd-webui unit service ..."
# 如果不是 /home/ubuntu/environment，请手动对齐 WORK HOME
cat > sd-webui.service <<EOF
[Unit]
Description=Stable Diffusion UI server
After=network.target
StartLimitIntervalSec=0

[Service]
WorkingDirectory=/home/ubuntu/environment/stable-diffusion-webui
ExecStart=/home/ubuntu/environment/stable-diffusion-webui/webui.sh --cors-allow-origins=* --enable-insecure-extension-access --skip-torch-cuda-test --no-half --listen
Type=simple
Restart=always
RestartSec=3
User=ubuntu
StartLimitAction=reboot

[Install]
WantedBy=default.target

EOF

sudo mv sd-webui.service /etc/systemd/system
sudo chown root:root /etc/systemd/system/sd-webui.service
sudo systemctl daemon-reload
sudo systemctl start sd-webui.service
sudo systemctl enable sd-webui.service

sudo chown -R ubuntu:ubuntu ${WORK_HOME}/stable-diffusion-webui/

echo -e "Start sd-webui service, check log by journalctl -u sd-webui -f ..."
sudo systemctl start sd-webui.service