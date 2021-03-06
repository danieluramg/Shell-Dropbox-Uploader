#!/bin/sh
#
# Dropbox Uploader Script v0.9.5
#
# Copyright (C) 2010-2012 Andrea Fabrizi <andrea.fabrizi@gmail.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
#
# Adaptado para BrazilFW 2.3x por daniel.uramg - 08/2012
#
#Set to 1 to enable DEBUG mode
DEBUG=0

#Set to 1 to enable VERBOSE mode
VERBOSE=1

#Default configuration file
PASTA=`dirname $0`; PASTA=`cd $PASTA; pwd`
CONFIG_FILE=/etc/.dropbox_uploader

#Don't edit these..
API_REQUEST_TOKEN_URL="https://api.dropbox.com/1/oauth/request_token"
API_USER_AUTH_URL="https://www2.dropbox.com/1/oauth/authorize"
API_ACCESS_TOKEN_URL="https://api.dropbox.com/1/oauth/access_token"
API_UPLOAD_URL="https://api-content.dropbox.com/1/files_put/dropbox"
API_DOWNLOAD_URL="https://api-content.dropbox.com/1/files/dropbox"
API_DELETE_URL="https://api.dropbox.com/1/fileops/delete"
API_METADATA_URL="https://api.dropbox.com/1/metadata/dropbox"
API_INFO_URL="https://api.dropbox.com/1/account/info"
APP_CREATE_URL="https://www2.dropbox.com/developers/apps"
RESPONSE_FILE="/tmp/du_resp_$RANDOM"
#BIN_DEPS="curl sed basename grep cut stat"
BIN_DEPS="sed basename grep cut"
VERSION="0.9.5"

umask 077

if [ $DEBUG -ne 0 ]; then
    set -x
    RESPONSE_FILE="/tmp/du_resp_debug"
fi

#Print verbose information depends on $VERBOSE variable
print()
{
    if [ $VERBOSE -eq 1 ]; then
	    echo -ne "$1";
    fi
}

#Returns unix timestamp
utime()
{
    echo $(date +%s)
}

#Remove temporary files
remove_temp_files()
{
    if [ $DEBUG -eq 0 ]; then
        rm -fr $RESPONSE_FILE
    fi
}

#Replace spaces
urlencode()
{
    str=$1
#    echo ${str// /%20}
	echo $str
}

#USAGE
usage() {
    echo -e
    echo -e "Dropbox Uploader v$VERSION"
    echo -e "Andrea Fabrizi - andrea.fabrizi@gmail.com"
    echo -e "Adaptado para BrazilFW 2.3x e traduzido para pt-BR por\nDaniel Plácido - daniel.uramg@gmail.com\n"
    echo -e "Uso: $0 COMANDO [PARAMETRO]..."
    echo -e "\nComandos:"
    
    echo -e "\t upload   [ARQUIVO_LOCAL]  <ARQUIVO_REMOTO>"
    echo -e "\t download [ARQUIVO_REMOTO] <ARQUIVO_LOCAL>"
    echo -e "\t delete   [ARQUIVO_REMOTO]"
    echo -e "\t info"
    echo -e "\t unlink"
    
    echo -e "\nPara mais exemplos visite o site do desenvolvedor:"
    echo -en "http://www.andreafabrizi.it/?dropbox_uploader\n\n"
    remove_temp_files
    exit 1
}

#CHECK DEPENDENCIES
for i in $BIN_DEPS; do
    which $i > /dev/null
    if [ $? -ne 0 ]; then
        echo -e "Erro: Arquivo de dependencia não encontrado: $i"
        remove_temp_files
        exit 1
    fi
done

#CHECKING FOR AUTH FILE
if [ -f "$CONFIG_FILE" ]; then
      
    #Loading data...
    APPKEY=$(sed -n -e 's/APPKEY:\([a-z A-Z 0-9]*\)/\1/p' "$CONFIG_FILE")
    APPSECRET=$(sed -n -e 's/APPSECRET:\([a-z A-Z 0-9]*\)/\1/p' "$CONFIG_FILE")
    OAUTH_ACCESS_TOKEN_SECRET=$(sed -n -e 's/OAUTH_ACCESS_TOKEN_SECRET:\([a-z A-Z 0-9]*\)/\1/p' "$CONFIG_FILE")
    OAUTH_ACCESS_TOKEN=$(sed -n -e 's/OAUTH_ACCESS_TOKEN:\([a-z A-Z 0-9]*\)/\1/p' "$CONFIG_FILE")
    
    #Checking the loaded data
    if [ -z "$APPKEY" -o -z "$APPSECRET" -o -z "$OAUTH_ACCESS_TOKEN_SECRET" -o -z "$OAUTH_ACCESS_TOKEN" ]; then
        echo -ne "Erro carregando dados de $CONFIG_FILE...\n"
        echo -ne "É recomendado que execute $0 unlink\n"
        remove_temp_files
        exit 1
    fi

#NEW SETUP...
else

    echo -ne "\n Esta é a primeira vez que você executa este script.\n"
    echo -ne " Por favor abra esta URL no seu navegador e acesse sua conta:\n\n -> $APP_CREATE_URL\n"
    echo -ne "\n Clique em \"Create an App\" e preencha o\n"
    echo -ne " formulário com os seguintes dados:\n\n"
    echo -ne "  App name: EasyBackup$RANDOM$RANDOM\n"
    echo -ne "  Description: O que você quiser...\n"
    echo -ne "  Access level: Full Dropbox\n\n"
    echo -ne " Clique no botão \"Create\".\n\n"
    
    echo -ne " Quando seu aplicativo novo for criado com sucesso, por favor insira o \n"
    echo -ne " App Key e App Secret:\n\n"

    #Getting the app key and secret from the user
    while (true); do
        
        echo -n " # App key: "
        read APPKEY

        echo -n " # App secret: "
        read APPSECRET

        echo -ne "\n > App key é $APPKEY e App secret é $APPSECRET, está certo? [y/n]"
        read answer
        if [ "$answer" == "y" ]; then
            break;
        fi

    done

    #TOKEN REQUESTS
    echo -ne "\n > Token request... "
    time=$(utime)
    /usr/local/bin/./curl -k  -s --show-error -i -o $RESPONSE_FILE --data "oauth_consumer_key=$APPKEY&oauth_signature_method=PLAINTEXT&oauth_signature=$APPSECRET%26&oauth_timestamp=$time&oauth_nonce=$RANDOM" "$API_REQUEST_TOKEN_URL"
echo 1
    OAUTH_TOKEN_SECRET=$(sed -n -e 's/oauth_token_secret=\([a-z A-Z 0-9]*\).*/\1/p' "$RESPONSE_FILE")
    OAUTH_TOKEN=$(sed -n -e 's/.*oauth_token=\([a-z A-Z 0-9]*\)/\1/p' "$RESPONSE_FILE")

    if [ -n "$OAUTH_TOKEN" -a -n "$OAUTH_TOKEN_SECRET" ]; then
        echo -ne "OK\n"
    else
        echo -ne " ERRO\n\n Verifique seu App key e secret...\n\n"
        remove_temp_files
        exit 1
    fi

    while (true); do

        #USER AUTH
        echo -ne "\n Por favor acesse esta URL do seu navegador, e permita que EasyBackup\n"
        echo -ne " acesse sua conta Dropbox:\n\n --> ${API_USER_AUTH_URL}?oauth_token=$OAUTH_TOKEN\n"
        echo -ne "\nQuando fizer, pressione Enter para continuar...\n"
        read pausa

        #API_ACCESS_TOKEN_URL
        echo -ne " > Access Token request... "
        time=$(utime)
        /usr/local/bin/./curl -k  -s --show-error -i -o $RESPONSE_FILE --data "oauth_consumer_key=$APPKEY&oauth_token=$OAUTH_TOKEN&oauth_signature_method=PLAINTEXT&oauth_signature=$APPSECRET%26$OAUTH_TOKEN_SECRET&oauth_timestamp=$time&oauth_nonce=$RANDOM" "$API_ACCESS_TOKEN_URL"
echo 2
        OAUTH_ACCESS_TOKEN_SECRET=$(sed -n -e 's/oauth_token_secret=\([a-z A-Z 0-9]*\)&.*/\1/p' "$RESPONSE_FILE")
        OAUTH_ACCESS_TOKEN=$(sed -n -e 's/.*oauth_token=\([a-z A-Z 0-9]*\)&.*/\1/p' "$RESPONSE_FILE")
        OAUTH_ACCESS_UID=$(sed -n -e 's/.*uid=\([0-9]*\)/\1/p' "$RESPONSE_FILE")
        
        if [ -n "$OAUTH_ACCESS_TOKEN" -a -n "$OAUTH_ACCESS_TOKEN_SECRET" -a -n "$OAUTH_ACCESS_UID" ]; then
            echo -ne "OK\n"
            
            #Saving data
            echo "APPKEY:$APPKEY" > "$CONFIG_FILE"
            echo "APPSECRET:$APPSECRET" >> "$CONFIG_FILE"
            echo "OAUTH_ACCESS_TOKEN:$OAUTH_ACCESS_TOKEN" >> "$CONFIG_FILE"
            echo "OAUTH_ACCESS_TOKEN_SECRET:$OAUTH_ACCESS_TOKEN_SECRET" >> "$CONFIG_FILE"
            
            echo -ne "\n Configuração completa!\n"
            break
        else
            print " ERRO\n"
        fi

    done;
    
    remove_temp_files     
    exit 0
fi

COMMAND=$1

#CHECKING PARAMS VALUES
case $COMMAND in

upload)

    FILE_SRC=$2
    FILE_DST=$(urlencode "$3")

    #Checking FILE_SRC
    if [ ! -f "$FILE_SRC" ]; then
        echo -e "Por favor especifique um caminho válido!"
        remove_temp_files
        exit 1
    fi
    
    #Checking FILE_DST
    if [ -z "$FILE_DST" ]; then
        FILE_DST=$(basename "$FILE_SRC")
    fi    
    
    ;;

download)

    FILE_SRC=$(urlencode "$2")
    FILE_DST=$3    

    #Checking FILE_SRC
    if [ -z "$FILE_SRC" ]; then
        echo -e "Por favor especifique um caminho válido!"
        remove_temp_files
        exit 1
    fi
    
    #Checking FILE_DST
    if [ -z "$FILE_DST" ]; then
        FILE_DST=$(basename "$FILE_SRC")
    fi
    
    ;;
    
info)
    #Nothing to do...
    ;;

delete)

    FILE_DST=$(urlencode "$2")    

    #Checking FILE_DST
    if [ -z "$FILE_DST" ]; then
        echo -e "Por favor especifique um destino válido para o arquivo!"
        remove_temp_files
        exit 1
    fi

    ;;

list)

    DIR_DST=$(urlencode "$2")    

    #Checking DIR_DST
    if [ -z "$DIR_DST" ]; then
        echo -e "Por favor especifique um diretório válido do Dropbox!"
        remove_temp_files
        exit 1
    fi

    ;;
    
unlink)
    #Nothing to do...
    ;;
        
*)
    usage
    ;;
esac

################
#### START  ####
################

#COMMAND EXECUTION
case "$COMMAND" in

    upload)

#        if [ $(stat --format="%s" "$FILE_SRC") -gt 150000000 ]; then
#            print " > ERRO\n"
#            print "   Devido a uma limitação na API do Dropbox você não pode fazer Upload de arquivos\n"
#            print "   maiores que 150Mb.\n"
#            remove_temp_files
#            exit 1
#        fi

        #Show the progress bar during the file upload
        if [ $VERBOSE -eq 1 ]; then
	        CURL_PARAMETERS="--progress-bar"
        else
	        CURL_PARAMETERS="-s --show-error"
        fi
     
        print " > Uploading $FILE_SRC to $FILE_DST... \n"  
        time=$(utime)
        /usr/local/bin/./curl -k  $CURL_PARAMETERS -i -o "$RESPONSE_FILE" --upload-file "$FILE_SRC" "$API_UPLOAD_URL/$FILE_DST?oauth_consumer_key=$APPKEY&oauth_token=$OAUTH_ACCESS_TOKEN&oauth_signature_method=PLAINTEXT&oauth_signature=$APPSECRET%26$OAUTH_ACCESS_TOKEN_SECRET&oauth_timestamp=$time&oauth_nonce=$RANDOM"
echo 3
               
        #Check
        grep "HTTP/1.1 200 OK" "$RESPONSE_FILE" > /dev/null
        if [ $? -eq 0 ]; then
            print " > PRONTO\n"
        else
            print " > ERRO\n"
		cat $RESPONSE_FILE
            print "   Se este problema persistir, tente desvincular este script de sua\n"
            print "   conta Dropbox, e configure novamente ($0 unlink).\n"
            remove_temp_files
            exit 1
        fi
        
        ;;


    download)

        #Show the progress bar during the file download
        if [ $VERBOSE -eq 1 ]; then
	        CURL_PARAMETERS="--progress-bar"
        else
	        CURL_PARAMETERS="-s --show-error"
        fi
     
        print " > Downloading $FILE_SRC to $FILE_DST... \n"  
        time=$(utime)
        /usr/local/bin/./curl -k  $CURL_PARAMETERS -D "$RESPONSE_FILE" -o "$FILE_DST" "$API_DOWNLOAD_URL/$FILE_SRC?oauth_consumer_key=$APPKEY&oauth_token=$OAUTH_ACCESS_TOKEN&oauth_signature_method=PLAINTEXT&oauth_signature=$APPSECRET%26$OAUTH_ACCESS_TOKEN_SECRET&oauth_timestamp=$time&oauth_nonce=$RANDOM"
echo 4
               
        #Check
        grep "HTTP/1.1 200 OK" "$RESPONSE_FILE" > /dev/null
        if [ $? -eq 0 ]; then
            print " > PRONTO\n"
        else
            print " > ERRO\n"
            print "   Se este problema persistir, tente desvincular este script de sua\n"
            print "   conta Dropbox, e configure novamente ($0 unlink).\n"
            rm -fr "$FILE_DST"
            remove_temp_files
            exit 1
        fi
         
        ;;


    info)
     
        print "Dropbox Uploader v$VERSION\n\n"
        print " > Requisitando informações... \n"  
        time=$(utime)
        CURL_PARAMETERS="-s --show-error"
        /usr/local/bin/./curl -k  $CURL_PARAMETERS -i -o "$RESPONSE_FILE" --data "oauth_consumer_key=$APPKEY&oauth_token=$OAUTH_ACCESS_TOKEN&oauth_signature_method=PLAINTEXT&oauth_signature=$APPSECRET%26$OAUTH_ACCESS_TOKEN_SECRET&oauth_timestamp=$time&oauth_nonce=$RANDOM" "$API_INFO_URL"
echo 5

        #Check
        grep "HTTP/1.1 200 OK" "$RESPONSE_FILE" > /dev/null
        if [ $? -eq 0 ]; then
        
            echo -ne "\nName:\t"
            sed -n -e 's/.*"display_name":\s*"*\([^"]*\)",.*/\1/p' "$RESPONSE_FILE"

            echo -ne "\nUID:\t"
            sed -n -e 's/.*"uid":\s*"*\([^"]*\)"*,.*/\1/p' "$RESPONSE_FILE"

            echo -ne "\nEmail:\t"
            sed -n -e 's/.*"email":\s*"*\([^"]*\)"*.*/\1/p' "$RESPONSE_FILE"
            
            echo -ne "\nQuota:\t"
            sed -n -e 's/.*"quota":\s*\([0-9]*\).*/\1/p' "$RESPONSE_FILE"

            echo -ne "\nUsed:\t"
            sed -n -e 's/.*"normal":\s*\([0-9]*\).*/\1/p' "$RESPONSE_FILE"
                    
            echo ""
            
        else
            print " > ERRO\n"
            print "   Se este problema persistir, tente desvincular este script de sua\n"
            print "   conta Dropbox, e configure novamente ($0 unlink).\n"
            remove_temp_files
            exit 1
        fi
                         
        ;;


    unlink)

        echo -ne "\n Você deseja realmente desvincular este script de sua conta Dropbox? [y/n]"
        read answer
        if [ "$answer" == "y" ]; then
            rm -fr "$CONFIG_FILE"
            echo -ne "Pronto!\n"
        fi
        
        ;;


   delete)
     
        print " > Deleting $FILE_DST... "  
        time=$(utime)
        CURL_PARAMETERS="-s --show-error"
        /usr/local/bin/./curl -k  $CURL_PARAMETERS -i -o "$RESPONSE_FILE" --data "oauth_consumer_key=$APPKEY&oauth_token=$OAUTH_ACCESS_TOKEN&oauth_signature_method=PLAINTEXT&oauth_signature=$APPSECRET%26$OAUTH_ACCESS_TOKEN_SECRET&oauth_timestamp=$time&oauth_nonce=$RANDOM&root=dropbox&path=$FILE_DST" "$API_DELETE_URL"
echo 6

        #Check
        grep "HTTP/1.1 200 OK" "$RESPONSE_FILE" > /dev/null
        if [ $? -eq 0 ]; then
            print "PRONTO\n"
        else    
            print "ERRO\n"
            remove_temp_files
            exit 1
        fi
        ;;


   list)
     
        print " > Listando $DIR_DST... "  
        time=$(utime)
        CURL_PARAMETERS="-s --show-error"
        /usr/local/bin/./curl -k  $CURL_PARAMETERS -i -o "$RESPONSE_FILE" "$API_METADATA_URL/$DIR_DST?oauth_consumer_key=$APPKEY&oauth_token=$OAUTH_ACCESS_TOKEN&oauth_signature_method=PLAINTEXT&oauth_signature=$APPSECRET%26$OAUTH_ACCESS_TOKEN_SECRET&oauth_timestamp=$time&oauth_nonce=$RANDOM"
echo 7
       
        #Check
        grep "HTTP/1.1 200 OK" "$RESPONSE_FILE" > /dev/null
        if [ $? -eq 0 ]; then
                  
            IS_DIR=$(head -c1000 "$RESPONSE_FILE" | sed -n -e 's/^.*"is_dir":\s*\([^,]*\),.*/\1/p')
            
            #It's a directory
            if [ "$IS_DIR" == "true" ]; then
            
                print "PRONTO\n"
            
                #Extracting directory content [...]
                DIR_CONTENT=$(sed -n -e 's/[^[]*\[\([^]]*\).*/\1/p' "$RESPONSE_FILE")
                
                #Replace "}, {" with "}\n{"
                DIR_CONTENT=$(echo "$DIR_CONTENT" | sed 's/},\s*{/\}\r\n\{/g')
                
                #Extracing files and subfolders
                echo "$DIR_CONTENT" | sed -n -e 's/.*"path":\s*"\([^"]*\)",.*"is_dir":\s*\([^"]*\),.*/\1\t\2/p' > $RESPONSE_FILE
                
                #Foreach line...
                while read line; do
                
                    FILE=$(echo "$line" | cut -f 1)
                    FILE=$(basename "$FILE")
                    TYPE=$(echo "$line" | cut -f 2)
                    
                    if [ "$TYPE" == "false" ]; then
                        echo " [F] $FILE"
                    else
                        echo " [D] $FILE"
                    fi
                done < $RESPONSE_FILE
            
            #It's a file
            else
                print "ERRO $DIR_DST Nào é um diretório!\n"
                remove_temp_files
                exit 1
            fi
            
        else    
            print "ERRO\n"
            remove_temp_files
            exit 1
        fi
        ;;
   
    *)
        usage
        ;;
        
esac

remove_temp_files
exit 0
