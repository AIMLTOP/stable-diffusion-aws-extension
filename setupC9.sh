#!/bin/bash
set -e # 在脚本执行过程中，如果任何语句的执行结果非真（返回非零状态），那么整个脚本就会立即终止执行
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

sudo apt-get update
sudo apt install software-properties-common -y
sudo add-apt-repository ppa:deadsnakes/ppa -y
sudo apt install wget git build-essential net-tools libgl1 needrestart -y # python3 python3.8-venv python3.10 python3.10-venv
sudo sed -i "/#\$nrconf{restart} = 'i';/s/.*/\$nrconf{restart} = 'a';/" /etc/needrestart/needrestart.conf

cd /home/ubuntu

echo -e "Clone AUTOMATIC1111 WebUI and set to supported version ..."
git clone https://github.com/AUTOMATIC1111/stable-diffusion-webui.git
cd stable-diffusion-webui
git reset --hard 68f336bd994bed5442ad95bad6b6ad5564a5409a

cd extensions
echo -e "Add aws related extensions..."

git clone https://github.com/awslabs/stable-diffusion-aws-extension.git
cd stable-diffusion-aws-extension/
./pre-flight.sh -f # sync version

# git clone https://github.com/journey-ad/sd-webui-bilingual-localization.git
# git clone https://github.com/wfjsw/stable-diffusion-webui-localization-zh_Hans.git
# git clone https://github.com/Physton/sd-webui-prompt-all-in-one.git
# git clone https://github.com/AlUlkesh/stable-diffusion-webui-images-browser

cd ..
sudo chown -R ubuntu:ubuntu stable-diffusion-aws-extension/ sd_dreambooth_extension/ sd-webui-controlnet/ ../../stable-diffusion-webui/
cd ..
cd models/Stable-diffusion/

echo -e "Download models ..."
# wget -O sd_xl_base_1.0.safetensors https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/resolve/main/sd_xl_base_1.0.safetensors             
wget https://aws-gcr-solutions.s3.amazonaws.com/stable-diffusion-aws-extension-github-mainline/models/LahCuteCartoonSDXL_alpha.safetensors

sudo mkdir ../Lora
sudo chown -R ubuntu:ubuntu ../Lora            
cd ../Lora
wget https://aws-gcr-solutions.s3.amazonaws.com/stable-diffusion-aws-extension-github-mainline/models/nendoroid_xl_v7.safetensors
cd ../..

# sudo -u ubuntu python3 -m venv venv
# source venv/bin/activate
pip install httpx==0.22.0
pip install httpcore==0.14.7

echo -e "Configue sd unit service ..."

password=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 17 ; echo '')
cat > sd.service <<EOF
[Unit]
Description=Stable Diffusion UI server
After=network.target
StartLimitIntervalSec=0

[Service]
WorkingDirectory=/home/ubuntu/stable-diffusion-webui
ExecStart=/home/ubuntu/stable-diffusion-webui/webui.sh --gradio-auth admin:${password} --cors-allow-origins=* --enable-insecure-extension-access --skip-torch-cuda-test --no-half --listen
Type=simple
Restart=always
RestartSec=3
User=ubuntu
StartLimitAction=reboot

[Install]
WantedBy=default.target

EOF
sudo mv sd.service /etc/systemd/system
sudo chown root:root /etc/systemd/system/sd.service
sudo systemctl daemon-reload

sudo systemctl enable sd.service

echo -e "Start sd service, check log by journalctl -u sd -f ..."
sudo systemctl start sd.service