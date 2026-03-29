# -proxmox-ts6-beta-server

Скрипт установки **TeamSpeak 6 Server** (Linux amd64) на **Debian 12** с **systemd** и автозапуском при загрузке.

## Требования

| | |
|---|---|
| **ОС** | Debian 12 (bookworm), 64-bit |
| **Архитектура** | x86_64 (amd64) |
| **RAM** | от ~512 МБ (лучше 1 ГБ и выше) |
| **Диск** | ~100 МБ под бинарники + место под БД и логи в `/opt/teamspeak6` |
| **Права** | установка только от root (`sudo`) |
| **Сеть** | исходящий HTTPS для скачивания релиза; для клиентов — открытые порты ниже |

Скрипт рассчитан на «чистую» установку в CT/VM (например, **Proxmox LXC** с шаблоном Debian 12). Другие дистрибутивы не тестировались: используются `apt-get` и пути Debian.

## Порты

Откройте на хосте / у провайдера / в Proxmox (firewall, Security Groups):

| Порт | Протокол | Назначение |
|------|-----------|------------|
| **9987** | UDP | Голос (подключение клиента) |
| **30033** | TCP | Передача файлов |

Опционально (по умолчанию в конфиге TS6 часто выключены): Query/Web — см. документацию TeamSpeak 6.

## Быстрая установка

```bash
cd /tmp
wget -O teamspeak-server.sh https://raw.githubusercontent.com/Doomer94/-proxmox-ts6-beta-server/main/teamspeak-server.sh
chmod +x teamspeak-server.sh
sudo ./teamspeak-server.sh
```

Локально (клон репозитория):

```bash
chmod +x teamspeak-server.sh
sudo ./teamspeak-server.sh
```

### Переменные окружения (необязательно)

| Переменная | Описание |
|------------|----------|
| `TS_URL` | URL архива `.tar.bz2` (по умолчанию — релиз beta8 с GitHub) |
| `INSTALL_DIR` | Каталог установки (по умолчанию `/opt/teamspeak6`) |
| `TS_USER` | Системный пользователь процесса (по умолчанию `teamspeak`) |
| `OPEN_UFW=1` | Добавить правила в UFW для портов голоса и файлов |

Пример:

```bash
sudo OPEN_UFW=1 ./teamspeak-server.sh
```

## После установки

Скрипт в конце выводит:

1. **Адрес подключения** — публичный IP (если доступен) и локальные IP с портом **9987** (UDP).
2. **ServerAdmin privilege key** — не пароль, а одноразовый ключ для выдачи прав администратора при **первом** подключении в клиенте TeamSpeak 6. Если сервер уже запускался ранее, строка может не повториться — смотрите `journalctl -u teamspeak6`.

Полезные команды:

```bash
systemctl status teamspeak6
journalctl -u teamspeak6 -f
```