# Metabobank tools

## mb-validate

IDF/SDRF/データファイルをチェック。[ルール](https://www.ddbj.nig.ac.jp/metabobank/validation-e.html)   

```
singularity exec mb-tools.simg mb-validate -i IDF [-s SDRF] [-t BioSample tsv] [-o output directory of corrected file] [-a] [-m md5 checksum file] [-d]
```

* -i: IDF を指定（必須）
* -s: SDRF を指定。無い場合は IDF のパスから導出。例 study/MTBKS1/MTBKS1.idf.txt → study/MTBKS1/MTBKS1.sdrf.txt（任意）
* -t: BioSample tsv を指定。ある場合は BioSample との整合性チェックを実施（任意）
* -o: auto-correct された IDF/SDRF ファイルの出力ディレクトリ。デフォルトは IDF と同じ場所に MTBKS1.corrected.idf.txt のように生成（任意）
* -a: auto-correct を実施。デフォルトは未実施（任意）
* -m: md5 値を md5sum コマンドの出力ファイルとして指定。指定した場合、SDRF 中の md5 値は無視される（任意）
* -d: データファイル (raw, processed, maf) のチェックを実施

使い方の例

* auto-correct 無し
* データファイルチェック有り

```
singularity exec mb-tools.simg mb-validate -i study/MTBKS302/MTBKS302.idf.txt -d
```

加えて md5 値を MTBKS302.md ファイルとして指定。

```
singularity exec mb-tools.simg mb-validate -i study/MTBKS302/MTBKS302.idf.txt -d -m MTBKS302.md
```

* auto-correct 有り
* データファイルチェック無し
```
singularity exec mb-tools.simg mb-validate -i study/MTBKS302/MTBKS302.idf.txt -a
```

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