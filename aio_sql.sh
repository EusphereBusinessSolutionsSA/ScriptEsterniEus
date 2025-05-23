#!/usr/bin/env bash
set -euo pipefail

# Verifica esecuzione come root
if [[ "$(id -u)" -ne 0 ]]; then
  echo "Errore: eseguire questo script come root"
  exit 1
fi

echo "1. Aggiunta repository PHP 8.4"
apt update
apt install -y lsb-release ca-certificates apt-transport-https software-properties-common
add-apt-repository ppa:ondrej/php -y
apt update

echo "2. Installazione PHP 8.4 e moduli essenziali"
apt install -y php8.4-fpm php8.4-cli php8.4-common php8.4-xml php8.4-mbstring php8.4-curl php8.4-zip

echo "3. Installazione tool di build e dipendenze ODBC"
apt install -y php8.4-dev php-pear unixodbc-dev odbcinst unixodbc build-essential gcc g++ make autoconf pkg-config

echo "4. Rimozione di eventuali moduli SQLSRV precedenti"
pecl uninstall sqlsrv pdo_sqlsrv || true
rm -f /etc/php/8.4/*/conf.d/*sqlsrv*.ini

echo "5. Compilazione e installazione driver SQLSRV via PECL"
pecl channel-update pecl.php.net
pecl install -f sqlsrv
pecl install -f pdo_sqlsrv

echo "6. Verifica presenza dei file .so"
EXT_DIR=$(php -i | awk '/extension_dir/ {print $3; exit}')
if [[ ! -f "$EXT_DIR/sqlsrv.so" ]]; then
  echo "Errore: sqlsrv.so non trovato in $EXT_DIR"
  exit 1
fi
if [[ ! -f "$EXT_DIR/pdo_sqlsrv.so" ]]; then
  echo "Errore: pdo_sqlsrv.so non trovato in $EXT_DIR"
  exit 1
fi

echo "7. Abilitazione delle estensioni PHP"
echo extension=sqlsrv.so   > /etc/php/8.4/mods-available/sqlsrv.ini
echo extension=pdo_sqlsrv.so > /etc/php/8.4/mods-available/pdo_sqlsrv.ini
phpenmod sqlsrv pdo_sqlsrv

echo "8. Riavvio PHP-FPM e reload Nginx"
systemctl restart php8.4-fpm
if systemctl list-units --type=service --all | grep -q '^nginx.service'; then
  systemctl reload nginx
else
  echo "Avviso: nginx.service non presente, skip reload"
fi

echo "9. Verifica caricamento estensioni"
if php -m | grep -q sqlsrv; then
  echo "  sqlsrv: CARICATO"
else
  echo "  sqlsrv: ERRORE – non caricato"
  exit 1
fi
if php -m | grep -q pdo_sqlsrv; then
  echo "  pdo_sqlsrv: CARICATO"
else
  echo "  pdo_sqlsrv: ERRORE – non caricato"
  exit 1
fi

echo "Informazioni su sqlsrv:"
php --ri sqlsrv
echo "Informazioni su pdo_sqlsrv:"
php --ri pdo_sqlsrv

echo "10. Rimozione PHP 8.3 (se presente)"
if dpkg -l | grep -q '^ii\s*php8.3'; then
  apt purge -y php8.3*
  apt autoremove -y
else
  echo "  nessun pacchetto php8.3 installato"
fi

echo "Installazione completata con successo"
