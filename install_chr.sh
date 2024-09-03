#!/bin/bash -e

echo
echo "=== azadrah.org ==="
echo "=== https://github.com/azadrahorg ==="
echo "=== MikroTik 7 Installer ==="
echo

# Verifica se os comandos necessários estão disponíveis
for cmd in wget gunzip dd lsblk ip df; do
    if ! command -v $cmd &> /dev/null; then
        echo "Erro: Comando $cmd não encontrado."
        exit 1
    fi
done

sleep 3
wget https://download.mikrotik.com/routeros/7.11.2/chr-7.11.2.img.zip -O chr.img.zip

# Verifica se o download foi bem-sucedido
if [[ $? -ne 0 ]]; then
    echo "Erro no download da imagem."
    exit 1
fi

gunzip -c chr.img.zip > chr.img

# Verifica se a imagem foi descompactada corretamente
if [[ ! -f chr.img ]]; then
    echo "Erro ao descompactar a imagem."
    exit 1
fi

# Seleciona o dispositivo de armazenamento físico (ignora loopbacks e dispositivos removíveis)
STORAGE=$(lsblk -nd -o NAME,TYPE | grep 'disk' | awk '{print $1}' | head -n 1)
if [[ -z $STORAGE ]]; then
    echo "Erro ao identificar o dispositivo de armazenamento."
    exit 1
fi
echo "STORAGE é /dev/$STORAGE"

# Verifica o espaço disponível no dispositivo de armazenamento
SPACE_AVAILABLE=$(df -h | grep "/dev/$STORAGE" | awk '{print $4}')
if [[ -z $SPACE_AVAILABLE ]]; then
    echo "Erro ao verificar o espaço disponível em /dev/$STORAGE."
    exit 1
fi
echo "Espaço disponível em /dev/$STORAGE: $SPACE_AVAILABLE"

ETH=$(ip route show default | sed -n 's/.* dev \([^\ ]*\) .*/\1/p')
if [[ -z $ETH ]]; then
    echo "Erro ao identificar a interface de rede."
    exit 1
fi
echo "ETH é $ETH"

ADDRESS=$(ip addr show $ETH | grep global | cut -d' ' -f 6 | head -n 1)
if [[ -z $ADDRESS ]]; then
    echo "Erro ao identificar o endereço IP."
    exit 1
fi
echo "ADDRESS é $ADDRESS"

GATEWAY=$(ip route list | grep default | cut -d' ' -f 3)
if [[ -z $GATEWAY ]]; then
    echo "Erro ao identificar o gateway."
    exit 1
fi
echo "GATEWAY é $GATEWAY"

sleep 5

# Verifica se o usuário tem permissões adequadas para gravar no dispositivo
if [[ ! -w /dev/$STORAGE ]]; then
    echo "Erro: Você não tem permissões para gravar em /dev/$STORAGE. Execute como root."
    exit 1
fi

# Grava a imagem no dispositivo de armazenamento físico
dd if=chr.img of=/dev/$STORAGE bs=4M oflag=sync

if [[ $? -eq 0 ]]; then
    echo "Instalação concluída. Reiniciando o sistema..."
    echo 1 > /proc/sys/kernel/sysrq
    echo b > /proc/sysrq-trigger
else
    echo "Erro durante a gravação da imagem no dispositivo de armazenamento."
    exit 1
fi
