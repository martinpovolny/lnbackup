#!/bin/bash

###################################### DEFINICE FUNKCI ##############################################

###################################### FUNKCE NAPOVEDA ##############################################

napoveda() {

        echo "sql_backup [volby]";
        echo "Volby:";
        echo "      --mysql		Zalohovani MySQL";
        echo "      --postgresql	Zalohovani PostgreSQL";
        echo "      --help		Napoveda";
return 0;
}


###################################### FUNKCE ZALOHA ##############################################

zaloha() {
  #kontrola a includovani souboru s vyjimkami DB ktere se nebudou zalohovat
  if [ -e /etc/default/lnbackup_databases ]; then
    . /etc/default/lnbackup_databases
  else 
      SKIP_MYSQL=""; # mysql DB ktere se nebudou zalohovat
      SKIP_POSTGRESQL=""; # postgre DB ktere se nebudou zalohovat
  fi;
  
  
  #nastaveni promenne ZALOHOVAT_DB a vlozeni template0 do SKIP_POSTGRESQL (zalohovani teto DB se defaultne preskakuje)
  if [ $DUMP == "/usr/bin/pg_dump" ]; then
      #pridavam defaultne template0 databazi protoze jeji zalohovani vzdy skonci s chybou (testovano na serverech emilka a hosting)
      SKIP_POSTGRESQL="$SKIP_POSTGRESQL template0";
      ZALOHOVAT_DB=$(diff  <(printf "%s\n" ${databases[@]} | sort)  <(printf "%s\n" ${SKIP_POSTGRESQL[@]} | sort) | egrep '^(<|>)' | tr -d '<> ') #vsechny DB - vzjimky DB = DB ktere se budou zalohovat
  fi
  
  
  #nastaveni promenne ZALOHOVAT_DB
  if [ $DUMP == "/usr/bin/mysqldump" ]; then
      ZALOHOVAT_DB=$(diff  <(printf "%s\n" ${databases[@]} | sort)  <(printf "%s\n" ${SKIP_MYSQL[@]} | sort) | egrep '^(<|>)' | tr -d '<> ') #vsechny DB -
  fi    
  
  
  
  for database in $ZALOHOVAT_DB;do
      if [ $DUMP == "/usr/bin/mysqldump" ]; then
      	$DUMP $database | grep -v 'Dump completed on ' | gzip --no-name > $TMP_DIR/$database.sql.gz # DUMP DB, vyjme se 'Dump completed on '(datum)pro pripad ze by byly soucasna i predchozi stejna a lisily se jen v datu  
      elif [ $DUMP == "/usr/bin/pg_dump" ]; then
      	su postgres -c "$DUMP $database | gzip --no-name > $TMP_DIR/$database.sql.gz" # su postgres je tam proto aby se dump provadel pod uzivatelem postgres
      fi
  
      #zjistit zda existuje vubec predchozi zaloha - v pripade ze ano tak porovnavat, v pripade ze ne tak to tam rovnou nahrnout
      if [ -f $DST_DIR/$database.sql.gz ];then # test predchozi a soucasne DB, v pripade zmeny je stara DB prepsana, v pripade ze je stejna tak je ponechana
          #ls -l  $TMP_DIR/$database.sql.gz $DST_DIR/$database.sql.gz
          if ! /usr/bin/diff -q $TMP_DIR/$database.sql.gz $DST_DIR/$database.sql.gz > /dev/null; then # pokud DB nejsou stejne tak prepis posledni zalohu
              echo "prepisuji soubor $DST_DIR/$database.sql.gz novejsi verzi"
              mv $TMP_DIR/$database.sql.gz $DST_DIR/$database.sql.gz           
          else
              echo "mazu $TMP_DIR/$database.sql.gz" # 
              rm $TMP_DIR/$database.sql.gz # pokud jsou stejne tak smaze docas. adr. ktery slouzi pro porovnavani soucasne a minule DB
          fi
      else
          mv $TMP_DIR/$database.sql.gz $DST_DIR/$database.sql.gz # pripad kdy neexistovala predchozi DB
          echo "predchozi $DST_DIR/$database.sql.gz neexistovala, ukladam aktualni"
      fi
  done
  
  rmdir $TMP_DIR
  
  return 0;
}


####################################### SPUSTENI S ARGUMENTEM --mysql ###############################
if [ "${1}" == "--mysql" ]; then
       if [ -x /usr/bin/mysql ]; then

               MYSQL=/usr/bin/mysql
               DUMP=/usr/bin/mysqldump
               #TYPE=mysql
               #MD5SUM=/usr/bin/md5sum
               GREP=/bin/grep
               DST_DIR=/var/backups/mysql
               TMP_DIR=/tmp/sql


                mkdir -p $TMP_DIR
                mkdir -p $DST_DIR

               databases=`$MYSQL -B -e 'show databases;' | $GREP -v '^Database'` # do pro menne databazes se zapisi DB ktere jsou na serveru
         	zaloha
       else
               echo "na serveru neni nainstalovano mysql";
               exit 1
       fi
####################################### SPUSTENI S ARGUMENTEM --postgresql ###############################
elif [ "${1}" == "--postgresql" ]; then
       if [ -x /usr/bin/psql ]; then
               POSTGRES=/usr/bin/psql
               DUMP=/usr/bin/pg_dump
               #TYPE=postgres
               #MD5SUM=/usr/bin/md5sum
               GREP=/bin/grep
               DST_DIR=/var/backups/postgres
               TMP_DIR=/tmp/postgres
              
                mkdir -p $TMP_DIR
                #pridani prav aby uzivatel postgres mohl zapisovat do cilove slozky
                chmod o+w $TMP_DIR
                mkdir -p $DST_DIR
                #pridani prav aby uzivatel postgres mohl zapisovat do cilove slozky
                chmod o+w $DST_DIR
               
               databases=`su postgres -c "psql -l | egrep -v '(Name.*Owner.*Encoding|List of databases|----------|. rows|^$)' | cut -f 2 -d ' '"` #do databases se zapisi DB ktere jsou na serveru
               zaloha
       else
               echo "na serveru neni nainstalovan postgresql";
               exit 1
       fi
######################################## SPUSTENI S NAPOVEDY (ARGUMENTEM --help) ###############################
else
    napoveda
fi 
