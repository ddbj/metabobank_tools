# Metabobank tools

## mbexcel2idfsdrf.rb

MetaboBank metadata excel から IDF/SDRF tsv ファイルを生成  

Options  
* -i: MetaboBank metadata excel 
* -f: base filename (指定しない場合 .xlsx を除いたエクセルファイル名を使用)

```
ruby mbexcel2idfsdrf.rb -i MBS-22_1_LC-MS_metadata.xlsx -f test

test.idf.txt
test.sdrf.txt
```

```
ruby mbexcel2idfsdrf.rb -i MBS-22_1_LC-MS_metadata.xlsx

MBS-22_1_LC-MS_metadata.idf.txt
MBS-22_1_LC-MS_metadata.sdrf.txt
```

base filename をファイル名として IDF/SDRF ファイルが生成される  
* [base filename].idf.txt  
* [base filename].sdrf.txt

IDF は MAGE-TAB 1.1 以降を、SDRF は Source Name 以降を出力