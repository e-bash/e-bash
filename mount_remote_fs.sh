#!/bin/bash

REMOTE_HOST="dev-server"
LOG_FILE="/var/log/sshfs_mount.log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

# папки и режимы монтирования
declare -A REMOTE_PATHS=(
    # core - только для чтения
    ["/home/bitrix/core/images"]="ro:/var/www/remote/dev/core/images"
    ["/home/bitrix/core/upload"]="ro:/var/www/remote/dev/core/upload"
    ["/var/log"]="ro:/var/www/remote/dev/logs"
    # public - для чтения и записи
    ["/home/bitrix/ext_www/p3.b24dev.corp.ppricep.ru"]="rw:/var/www/remote/dev/public/main"
    ["/home/bitrix/ext_www/p3.crm.b24dev.corp.ppricep.ru"]="rw:/var/www/remote/dev/public/crm"
    ["/home/bitrix/ext_www/p3.pro.auto.b24dev.corp.ppricep.ru"]="rw:/var/www/remote/dev/public/pro"
    ["/home/bitrix/ext_www/p3.wagnermaier.b24dev.corp.ppricep.ru"]="rw:/var/www/remote/dev/public/wagnermaier"
    # core - для чтения и записи
    ["/home/bitrix/ext_www/p3.crm.b24dev.corp.ppricep.ru/bitrix"]="rw:/var/www/remote/dev/core/bitrix"
    ["/home/bitrix/ext_www/p3.crm.b24dev.corp.ppricep.ru/local"]="rw:/var/www/remote/dev/core/local"
    ["/home/bitrix/ext_www/p3.crm.b24dev.corp.ppricep.ru/logs"]="rw:/var/www/remote/dev/core/logs"
    ["/home/bitrix/ext_www/p3.crm.b24dev.corp.ppricep.ru/vendor"]="rw:/var/www/remote/dev/core/vendor"
)

# Проверка на наличие sshfs
if ! command -v sshfs &>/dev/null; then
    echo "$DATE - Ошибка: sshfs не установлен. Пожалуйста, установите его и попробуйте снова." | tee -a "$LOG_FILE"
    exit 1
fi

# Проверка доступности удаленного хоста
if ssh -q -o ConnectTimeout=5 $REMOTE_HOST exit; then
    echo "$DATE - VPN подключен (${REMOTE_HOST} доступен). Попытка монтирования удаленных папок..." | tee -a "$LOG_FILE"
    
    # Цикл по всем папкам и их режимам
    for REMOTE_PATH in "${!REMOTE_PATHS[@]}"; do
        # Разбор строки с режимом и локальным путем
        MOUNT_MODE="${REMOTE_PATHS[$REMOTE_PATH]%%:*}"
        LOCAL_PATH="${REMOTE_PATHS[$REMOTE_PATH]#*:}"
        
        # Проверка, смонтирована ли папка
        if mountpoint -q "$LOCAL_PATH"; then
            echo "$DATE - Папка уже смонтирована: $LOCAL_PATH" | tee -a "$LOG_FILE"
            continue
        fi

        # Отключение папки на случай, если она была смонтирована неправильно
        sudo fusermount -u "$LOCAL_PATH" 2>/dev/null

        # Монтирование папки
        if sshfs -o "$MOUNT_MODE,allow_other,reconnect,ServerAliveInterval=30,ServerAliveCountMax=20,compression=yes,cache=yes" "${REMOTE_HOST}:${REMOTE_PATH}" "$LOCAL_PATH"; then
            echo "$DATE - Папка ${REMOTE_HOST}:${REMOTE_PATH} успешно смонтирована в ${LOCAL_PATH} в режиме ${MOUNT_MODE}" | tee -a "$LOG_FILE"
        else 
            echo "$DATE - Не удалось подмонтировать папку ${REMOTE_HOST}:${REMOTE_PATH} в ${LOCAL_PATH} в режиме ${MOUNT_MODE}" | tee -a "$LOG_FILE"
        fi
    done
else
    echo "$DATE - VPN не подключен ($REMOTE_HOST не доступен). Пожалуйста, подключите VPN и повторите попытку." | tee -a "$LOG_FILE"
    exit 1
fi

echo "$DATE - Все операции монтирования завершены." | tee -a "$LOG_FILE"
