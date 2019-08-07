#!/bin/bash
if [ "$#" -ne 1 ]; then
  echo "Run with three arguements: Host User Password for MySQL"
  echo "Example ./runme.sh 1.1.1.1 root password"
  exit 1
fi


for x in *.7z
do
  table=${x%%.*}
  echo $table
  mkdir -p $table && cp "$x" $table
  cd  $table
  p7zip -d $x
  cp ../import.sql .
  sed -i "s/REPLACEME/$table/g" import.sql
  mysql -h $0 -u $1 -p$2 < import.sql
  cd ..
done
