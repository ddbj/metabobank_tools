# Metabobank tools

## excel2tsv.rb

MetaboBank metadata excel から IDF/SDRF tsv ファイルを生成  

```
ruby excel2tsv.rb -i MBS-22_1_LC-MS_metadata.xlsx -f test

test.idf.txt
test.sdrf.txt
```

* -i: MetaboBank metadata excel 
* -f: base filename

base filename をファイル名として IDF/SDRF ファイルが生成される  
* [base filename].idf.txt  
* [base filename].sdrf.txt







