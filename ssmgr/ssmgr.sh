#!/usr/bin/env bash
GREEN='\033[0;32m'
NC='\033[0m' # No Color

isRoot() {
  if [[ "$EUID" -ne 0 ]]; then
    echo "false"
  else
    echo "true"
  fi
}

init_release(){
  if [ -f /etc/os-release ]; then
      # freedesktop.org and systemd
      . /etc/os-release
      OS=$NAME
  elif type lsb_release >/dev/null 2>&1; then
      # linuxbase.org
      OS=$(lsb_release -si)
  elif [ -f /etc/lsb-release ]; then
      # For some versions of Debian/Ubuntu without lsb_release command
      . /etc/lsb-release
      OS=$DISTRIB_ID
  elif [ -f /etc/debian_version ]; then
      # Older Debian/Ubuntu/etc.
      OS=Debian
  elif [ -f /etc/SuSe-release ]; then
      # Older SuSE/etc.
      ...
  elif [ -f /etc/redhat-release ]; then
      # Older Red Hat, CentOS, etc.
      ...
  else
      # Fall back to uname, e.g. "Linux <version>", also works for BSD, etc.
      OS=$(uname -s)
  fi

  # convert string to lower case
  OS=`echo "$OS" | tr '[:upper:]' '[:lower:]'`

  if [[ $OS = *'ubuntu'* || $OS = *'debian'* ]]; then
    PM='apt'
  elif [[ $OS = *'centos'* ]]; then
    PM='yum'
  else
    exit 1
  fi
  # PM='apt'
}

# install shadowsocks
install_shadowsocks(){
  # init package manager
  init_release
  echo ${PM}
  #statements
  if [[ ${PM} = "apt" ]]; then
    apt-get install dnsutils -y
    apt install net-tools -y
    apt-get install python-pip -y
    apt-get install redis -y # install redis
  elif [[ ${PM} = "yum" ]]; then
    yum install bind-utils -y
    yum install net-tools -y
    yum install python-setuptools -y && easy_install pip
    yum install redis -y # install redis
  fi
  pip install shadowsocks
  # start ssserver and run manager background
  ssserver -m aes-256-cfb -p 12345 -k abcedf --manager-address 127.0.0.1:4000 --user nobody -d start
}

# Get public IP address
get_ip(){
    local IP=$(dig +short myip.opendns.com @resolver1.opendns.com)
    [ -z ${IP} ] && IP=$( wget -qO- -t1 -T2 ipv4.icanhazip.com )
    [ -z ${IP} ] && IP=$( wget -qO- -t1 -T2 ipinfo.io/ip )
    [ ! -z ${IP} ] && echo ${IP} || echo
}

config(){
  # download template file
  wget https://raw.githubusercontent.com/shellhub/shellhub/master/ssmgr/ss.template.yml
  wget https://raw.githubusercontent.com/shellhub/shellhub/master/ssmgr/webgui.template.yml

  # write webgui password
  read -p "Input webgui manage password:" password
  echo "password=${password}" >> config

  # generate ss.yml
  config=`cat ./config`
  templ=`cat ./ss.template.yml`
  printf "$config\ncat << EOF\n$templ\nEOF" | bash > ss.yml

  read -p "Install webgui(website) y/n?: y" webgui
  if [[ $webgui = "y" ]]; then
    # write ip address
    echo "IP=$(get_ip)" >> config
    # write email username
    read -p "Input your email address:" email_username
    echo "email_username=${email_username}" >> config

    # write email password
    read -p "Input your email password:" PASSWORD
    email_password=$PASSWORD
    echo "email_password=${email_password}" >> config

    # write alipay config
    read -p "Input alipay appid:" alipay_appid
    echo "alipay_appid=${alipay_appid}" >> config

    read -p "Input alipay_private_key:" alipay_private_key
    echo "alipay_private_key=${alipay_private_key}" >> config

    read -p "Input alipay_public_key:" alipay_public_key
    echo "alipay_public_key=${alipay_public_key}" >> config

    # generate webgui.yml
    config=`cat ./config`
    templ=`cat ./webgui.template.yml`
    printf "$config\ncat << EOF\n$templ\nEOF" | bash > webgui.yml
  else
    echo "no webgui selected!!!"
  fi
}

install_ssmgr(){
  curl -sL https://rpm.nodesource.com/setup_8.x | bash -
  yum install -y nodejs
  npm i -g shadowsocks-manager --unsafe-perm
}

run_ssgmr(){
  npm i -g pm2
  pm2 --name "ss" -f start ssmgr -x -- -c ss.yml
  pm2 --name "webgui" -f start ssmgr -x -- -c webgui.yml
}

go_workspace(){
  mkdir ~/.ssmgr/
  cd ~/.ssmgr/
}

run_redis(){
  nohup redis-server &
}

main(){
  #check root permission
  isRoot=$( isRoot )
  if [[ "${isRoot}" != "true" ]]; then
    echo -e "${RED_COLOR}error:${NO_COLOR}Please run this script as as root"
    exit 1
  else
    go_workspace
    install_shadowsocks
    install_ssmgr
    config
    run_redis
    run_ssgmr
  fi
}

# start run script
main
