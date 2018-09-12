# Copyright (c) 2018-present, Facebook, Inc.
# All rights reserved.
#
# This source code is licensed under the license found in the
# LICENSE file in the root directory of this source tree.
#

set -e

#
# Data preprocessing configuration
#

#N_MONO=10000000  # number of monolingual sentences for each language
N_MONO=10000000  # number of monolingual sentences for each language
N_ITER=0         # number of backtranslation iterations
N_THREADS=48     # number of threads in data preprocessing
#SRC=en           # source language
#TGT=fr           # target language
SRC=fr           # source language
TGT=en           # target language



#
# Initialize Moses and data paths
#

# main paths
UMT_PATH=$PWD/PBSMT
DATA_PATH=$PWD/data
MONO_PATH=$DATA_PATH/mono
PARA_PATH=$DATA_PATH/para
EMB_PATH=$DATA_PATH/embeddings

# create paths
mkdir -p $DATA_PATH
mkdir -p $MONO_PATH
mkdir -p $PARA_PATH
mkdir -p $EMB_PATH

# moses
#MOSES_PATH=/private/home/guismay/tools/mosesdecoder  # PATH_WHERE_YOU_INSTALLED_MOSES
MOSES_PATH=/n/rush_lab/jc/code/mosesdecoder # PATH_WHERE_YOU_INSTALLED_MOSES
TOKENIZER=$MOSES_PATH/scripts/tokenizer/tokenizer.perl
NORM_PUNC=$MOSES_PATH/scripts/tokenizer/normalize-punctuation.perl
INPUT_FROM_SGM=$MOSES_PATH/scripts/ems/support/input-from-sgm.perl
REM_NON_PRINT_CHAR=$MOSES_PATH/scripts/tokenizer/remove-non-printing-char.perl
TRAIN_TRUECASER=$MOSES_PATH/scripts/recaser/train-truecaser.perl
TRUECASER=$MOSES_PATH/scripts/recaser/truecase.perl
DETRUECASER=$MOSES_PATH/scripts/recaser/detruecase.perl
TRAIN_LM=$MOSES_PATH/bin/lmplz
TRAIN_MODEL=$MOSES_PATH/scripts/training/train-model.perl
MULTIBLEU=$MOSES_PATH/scripts/generic/multi-bleu.perl
MOSES_BIN=$MOSES_PATH/bin/moses

# training directory
TRAIN_DIR=$PWD/moses_train_$SRC-$TGT

# MUSE path
MUSE_PATH=$PWD/MUSE

# files full paths
EN_RAW=$MONO_PATH/all.en
FR_RAW=$MONO_PATH/all.fr
EN_TOK=$MONO_PATH/all.en.tok
FR_TOK=$MONO_PATH/all.fr.tok
EN_TRUE=$MONO_PATH/all.en.true
FR_TRUE=$MONO_PATH/all.fr.true
EN_VALID=$PARA_PATH/dev/newstest2013-ref.en
FR_VALID=$PARA_PATH/dev/newstest2013-ref.fr
EN_TEST=$PARA_PATH/dev/newstest2014-fren-src.en
FR_TEST=$PARA_PATH/dev/newstest2014-fren-src.fr
EN_TRUECASER=$DATA_PATH/en.truecaser
FR_TRUECASER=$DATA_PATH/fr.truecaser
EN_LM_ARPA=$DATA_PATH/en.lm.arpa
FR_LM_ARPA=$DATA_PATH/fr.lm.arpa
EN_LM_BLM=$DATA_PATH/en.lm.blm
FR_LM_BLM=$DATA_PATH/fr.lm.blm

if [[ $SRC = "en" ]]; then
    SRC_TRUE=$EN_TRUE
    TGT_TRUE=$FR_TRUE
    SRC_VALID=$EN_VALID
    TGT_VALID=$FR_VALID
    SRC_TEST=$EN_TEST
    TGT_TEST=$FR_TEST
else
    SRC_TRUE=$FR_TRUE
    TGT_TRUE=$EN_TRUE
    SRC_VALID=$FR_VALID
    TGT_VALID=$EN_VALID
    SRC_TEST=$FR_TEST
    TGT_TEST=$EN_TEST
fi

#
# Download and install tools
#

# Check Moses files
if ! [[ -f "$TOKENIZER" && -f "$NORM_PUNC" && -f "$INPUT_FROM_SGM" && -f "$REM_NON_PRINT_CHAR" && -f "$TRAIN_TRUECASER" && -f "$TRUECASER" && -f "$DETRUECASER" && -f "$TRAIN_MODEL" ]]; then
  echo "Some Moses files were not found."
  echo "Please update the MOSES variable to the path where you installed Moses."
  exit
fi
if ! [[ -f "$MOSES_BIN" ]]; then
  echo "Couldn't find Moses binary in: $MOSES_BIN"
  echo "Please check your installation."
  exit
fi
if ! [[ -f "$TRAIN_LM" ]]; then
  echo "Couldn't find language model trainer in: $TRAIN_LM"
  echo "Please install KenLM."
  exit
fi


# Download MUSE
if [ ! -d "$MUSE_PATH" ]; then
  echo "Cloning MUSE from GitHub repository..."
  git clone https://github.com/facebookresearch/MUSE.git
  cd $MUSE_PATH/data/
  ./get_evaluation.sh
fi
echo "MUSE found in: $MUSE_PATH"


#
# Download pretrained word embeddings
#

cd $EMB_PATH

if [ ! -f "wiki.en.300.vec.gz" ]; then
  echo "Downloading EN pretrained embeddings..."
  wget -c "https://s3.amazonaws.com/arrival/wiki.en.300.vec.gz"
fi
if [ ! -f "wiki.fr.300.vec.gz" ]; then
  echo "Downloading FR pretrained embeddings..."
  wget -c "https://s3.amazonaws.com/arrival/wiki.fr.300.vec.gz"
fi

if [ ! -f "wiki.en.300.vec" ]; then
  echo "Decompressing English pretrained embeddings..."
  gunzip -c wiki.en.300.vec.gz > wiki.en.300.vec
fi
if [ ! -f "wiki.fr.300.vec" ]; then
  echo "Decompressing French pretrained embeddings..."
  #gunzip -k wiki.fr.300.vec.gz
  gunzip -c wiki.fr.300.vec.gz > wiki.fr.300.vec
fi

EN_EMB=$EMB_PATH/wiki.en.300.vec
FR_EMB=$EMB_PATH/wiki.fr.300.vec
echo "Pretrained EN embeddings found in: $EN_EMB"
echo "Pretrained FR embeddings found in: $FR_EMB"

#
# Download monolingual data
#

cd $MONO_PATH

echo "Downloading English files..."
wget -c http://www.statmt.org/wmt14/training-monolingual-news-crawl/news.2007.en.shuffled.gz
wget -c http://www.statmt.org/wmt14/training-monolingual-news-crawl/news.2008.en.shuffled.gz
wget -c http://www.statmt.org/wmt14/training-monolingual-news-crawl/news.2009.en.shuffled.gz
wget -c http://www.statmt.org/wmt14/training-monolingual-news-crawl/news.2010.en.shuffled.gz
# below commented out
wget -c http://www.statmt.org/wmt14/training-monolingual-news-crawl/news.2011.en.shuffled.gz
wget -c http://www.statmt.org/wmt14/training-monolingual-news-crawl/news.2012.en.shuffled.gz
wget -c http://www.statmt.org/wmt14/training-monolingual-news-crawl/news.2013.en.shuffled.gz
wget -c http://www.statmt.org/wmt15/training-monolingual-news-crawl-v2/news.2014.en.shuffled.v2.gz
wget -c http://data.statmt.org/wmt16/translation-task/news.2015.en.shuffled.gz
wget -c http://data.statmt.org/wmt17/translation-task/news.2016.en.shuffled.gz
wget -c http://data.statmt.org/wmt18/translation-task/news.2017.en.shuffled.deduped.gz

echo "Downloading French files..."
wget -c http://www.statmt.org/wmt14/training-monolingual-news-crawl/news.2007.fr.shuffled.gz
wget -c http://www.statmt.org/wmt14/training-monolingual-news-crawl/news.2008.fr.shuffled.gz
wget -c http://www.statmt.org/wmt14/training-monolingual-news-crawl/news.2009.fr.shuffled.gz
wget -c http://www.statmt.org/wmt14/training-monolingual-news-crawl/news.2010.fr.shuffled.gz
# below commented out
wget -c http://www.statmt.org/wmt14/training-monolingual-news-crawl/news.2011.fr.shuffled.gz
wget -c http://www.statmt.org/wmt14/training-monolingual-news-crawl/news.2012.fr.shuffled.gz
wget -c http://www.statmt.org/wmt14/training-monolingual-news-crawl/news.2013.fr.shuffled.gz
wget -c http://www.statmt.org/wmt15/training-monolingual-news-crawl-v2/news.2014.fr.shuffled.v2.gz
wget -c http://data.statmt.org/wmt17/translation-task/news.2015.fr.shuffled.gz
wget -c http://data.statmt.org/wmt17/translation-task/news.2016.fr.shuffled.gz
wget -c http://data.statmt.org/wmt17/translation-task/news.2017.fr.shuffled.gz

# decompress monolingual data
for FILENAME in news*gz; do
  OUTPUT="${FILENAME::-3}"
  if [ ! -f "$OUTPUT" ]; then
    echo "Decompressing $FILENAME..."
    #gunzip -k $FILENAME
    gunzip -c $FILENAME > $OUTPUT
  else
    echo "$OUTPUT already decompressed."
  fi
done

# concatenate monolingual data files
if ! [[ -f "$EN_RAW" && -f "$FR_RAW" ]]; then
  echo "Concatenating monolingual data..."
  #cat $(ls news*en* | grep -v gz) | head -n $N_MONO > $SRC_RAW
  #cat $(ls news*fr* | grep -v gz) | head -n $N_MONO > $TGT_RAW
  cat $(ls news*en* | grep -v gz) > $EN_RAW
  cat $(ls news*fr* | grep -v gz) > $FR_RAW
fi
echo "EN monolingual data concatenated in: $EN_RAW"
echo "FR monolingual data concatenated in: $FR_RAW"

# check number of lines
#if ! [[ "$(wc -l < $SRC_RAW)" -eq "$N_MONO" ]]; then echo "ERROR: Number of lines doesn't match! Be sure you have $N_MONO sentences in your $SRC monolingual data."; exit; fi
#if ! [[ "$(wc -l < $TGT_RAW)" -eq "$N_MONO" ]]; then echo "ERROR: Number of lines doesn't match! Be sure you have $N_MONO sentences in your $TGT monolingual data."; exit; fi
echo "EN mono has $(wc -l $EN_RAW) lines"
echo "FR mono has $(wc -l $FR_RAW) lines"

# tokenize data
if ! [[ -f "$EN_TOK" && -f "$FR_TOK" ]]; then
  echo "Tokenize monolingual data..."
  cat $EN_RAW | $NORM_PUNC -l en | $TOKENIZER -l en -no-escape -threads $N_THREADS > $EN_TOK
  cat $FR_RAW | $NORM_PUNC -l fr | $TOKENIZER -l fr -no-escape -threads $N_THREADS > $FR_TOK
fi
echo "$EN monolingual data tokenized in: $EN_TOK"
echo "$FR monolingual data tokenized in: $FR_TOK"

# learn truecasers
if ! [[ -f "$EN_TRUECASER" && -f "$FR_TRUECASER" ]]; then
  echo "Learning truecasers..."
  $TRAIN_TRUECASER --model $EN_TRUECASER --corpus $EN_TOK
  $TRAIN_TRUECASER --model $FR_TRUECASER --corpus $FR_TOK
fi
echo "EN truecaser in: $EN_TRUECASER"
echo "FR truecaser in: $FR_TRUECASER"

# truecase data
if ! [[ -f "$EN_TRUE" && -f "$FR_TRUE" ]]; then
  echo "Truecsing monolingual data..."
  $TRUECASER --model $EN_TRUECASER < $EN_TOK > $EN_TRUE
  $TRUECASER --model $FR_TRUECASER < $FR_TOK > $FR_TRUE
fi
echo "EN monolingual data truecased in: $EN_TRUE"
echo "FR monolingual data truecased in: $FR_TRUE"

# learn language models
if ! [[ -f "$EN_LM_ARPA" && -f "$FR_LM_ARPA" ]]; then
  echo "Learning language models..."
  $TRAIN_LM -o 5 < $EN_TRUE > $EN_LM_ARPA
  $TRAIN_LM -o 5 < $FR_TRUE > $FR_LM_ARPA
fi
echo "EN language model in: $EN_LM_ARPA"
echo "FR language model in: $FR_LM_ARPA"

# binarize language models
if ! [[ -f "$EN_LM_BLM" && -f "$FR_LM_BLM" ]]; then
  echo "Binarizing language models..."
  $MOSES_PATH/bin/build_binary $EN_LM_ARPA $EN_LM_BLM
  $MOSES_PATH/bin/build_binary $FR_LM_ARPA $FR_LM_BLM
fi
echo "EN binarized language model in: $EN_LM_BLM"
echo "FR binarized language model in: $FR_LM_BLM"


#
# Download parallel data (for evaluation only)
#

cd $PARA_PATH

echo "Downloading parallel data..."
wget -c http://data.statmt.org/wmt17/translation-task/dev.tgz

echo "Extracting parallel data..."
tar -xzf dev.tgz

# check valid and test files are here
if ! [[ -f "$EN_VALID.sgm" ]]; then echo "$EN_VALID.sgm is not found!"; exit; fi
if ! [[ -f "$FR_VALID.sgm" ]]; then echo "$FR_VALID.sgm is not found!"; exit; fi
if ! [[ -f "$EN_TEST.sgm" ]]; then echo "$EN_TEST.sgm is not found!"; exit; fi
if ! [[ -f "$FR_TEST.sgm" ]]; then echo "$FR_TEST.sgm is not found!"; exit; fi

echo "Tokenizing valid and test data..."
$INPUT_FROM_SGM < $EN_VALID.sgm | $NORM_PUNC -l en | $REM_NON_PRINT_CHAR | $TOKENIZER -l en -no-escape -threads $N_THREADS > $EN_VALID.tok
$INPUT_FROM_SGM < $FR_VALID.sgm | $NORM_PUNC -l fr | $REM_NON_PRINT_CHAR | $TOKENIZER -l fr -no-escape -threads $N_THREADS > $FR_VALID.tok
$INPUT_FROM_SGM < $EN_TEST.sgm | $NORM_PUNC -l en | $REM_NON_PRINT_CHAR | $TOKENIZER -l en -no-escape -threads $N_THREADS > $EN_TEST.tok
$INPUT_FROM_SGM < $FR_TEST.sgm | $NORM_PUNC -l fr | $REM_NON_PRINT_CHAR | $TOKENIZER -l fr -no-escape -threads $N_THREADS > $FR_TEST.tok

echo "Truecasing valid and test data..."
$TRUECASER --model $EN_TRUECASER < $EN_VALID.tok > $EN_VALID.true
$TRUECASER --model $FR_TRUECASER < $FR_VALID.tok > $FR_VALID.true
$TRUECASER --model $EN_TRUECASER < $EN_TEST.tok > $EN_TEST.true
$TRUECASER --model $FR_TRUECASER < $FR_TEST.tok > $FR_TEST.true


#
# Running MUSE to generate cross-lingual embeddings
#

ALIGNED_EMBEDDINGS_EN=$MUSE_PATH/alignments/wiki-released-$SRC$TGT-identical_char/vectors-en.pth
ALIGNED_EMBEDDINGS_FR=$MUSE_PATH/alignments/wiki-released-$SRC$TGT-identical_char/vectors-fr.pth

if [[ $SRC = "en" ]]; then
    EMB_SRC=$EN_EMB
    EMB_TGT=$FR_EMB
    ALIGNED_EMBEDDINGS_SRC=$ALIGNED_EMBEDDINGS_EN
    ALIGNED_EMBEDDINGS_TGT=$ALIGNED_EMBEDDINGS_FR
    TGT_LM_BLM=$DATA_PATH/fr.lm.blm
else
    EMB_SRC=$FR_EMB
    EMB_TGT=$EN_EMB
    ALIGNED_EMBEDDINGS_SRC=$ALIGNED_EMBEDDINGS_FR
    ALIGNED_EMBEDDINGS_TGT=$ALIGNED_EMBEDDINGS_EN
    TGT_LM_BLM=$DATA_PATH/en.lm.blm
fi

if ! [[ -f "$ALIGNED_EMBEDDINGS_EN" && -f "$ALIGNED_EMBEDDINGS_FR" ]]; then
  rm -rf $MUSE_PATH/alignments/
  echo "Aligning embeddings with MUSE..."
  python $MUSE_PATH/supervised.py --src_lang $SRC --tgt_lang $TGT \
  --exp_path $MUSE_PATH --exp_name alignments --exp_id wiki-released-$SRC$TGT-identical_char \
  --src_emb $EMB_SRC \
  --tgt_emb $EMB_TGT \
  --n_refinement 5 --dico_train identical_char --export "pth"
fi
echo "EN aligned embeddings: $ALIGNED_EMBEDDINGS_EN"
echo "FR aligned embeddings: $ALIGNED_EMBEDDINGS_FR"
echo "SRC aligned emb: $ALIGNED_EMBEDDINGS_SRC"
echo "TGT aligned emb: $ALIGNED_EMBEDDINGS_TGT"

#
# Generating a phrase-table in an unsupervised way
#

PHRASE_TABLE_PATH=$MUSE_PATH/alignments/wiki-released-$SRC$TGT-identical_char/phrase-table.$SRC-$TGT.gz
if ! [[ -f "$PHRASE_TABLE_PATH" ]]; then
  echo "Generating unsupervised phrase-table"
  python $UMT_PATH/create-phrase-table.py \
  --src_lang $SRC \
  --tgt_lang $TGT \
  --src_emb $ALIGNED_EMBEDDINGS_SRC \
  --tgt_emb $ALIGNED_EMBEDDINGS_TGT \
  --csls 1 \
  --max_rank 200 \
  --max_vocab 300000 \
  --inverse_score 1 \
  --temperature 45 \
  --phrase_table_path ${PHRASE_TABLE_PATH::-3}
fi
echo "Phrase-table location: $PHRASE_TABLE_PATH"


#
# Train Moses on the generated phrase-table
#

rm -rf $TRAIN_DIR
echo "Generating Moses configuration in: $TRAIN_DIR"

echo "Creating default configuration file..."
$TRAIN_MODEL -root-dir $TRAIN_DIR \
-f $SRC -e $TGT -alignment grow-diag-final-and -reordering msd-bidirectional-fe \
-lm 0:5:$TGT_LM_BLM:8 -external-bin-dir $MOSES_PATH/tools \
-cores $N_THREADS -max-phrase-length=4 -score-options "--NoLex" -first-step=9 -last-step=9
CONFIG_PATH=$TRAIN_DIR/model/moses.ini

echo "Removing lexical reordering features ..."
mv $TRAIN_DIR/model/moses.ini $TRAIN_DIR/model/moses.ini.bkp
cat $TRAIN_DIR/model/moses.ini.bkp | grep -v LexicalReordering > $TRAIN_DIR/model/moses.ini

echo "Linking phrase-table path..."
ln -sf $PHRASE_TABLE_PATH $TRAIN_DIR/model/phrase-table.gz

echo "Translating test sentences..."
$MOSES_BIN -threads $N_THREADS -f $CONFIG_PATH < $SRC_TEST.true > $TRAIN_DIR/test.$TGT.hyp.true

echo "Detruecasing hypothesis..."
$DETRUECASER < $TRAIN_DIR/test.$TGT.hyp.true > $TRAIN_DIR/test.$TGT.hyp.tok

echo "Evaluating translations..."
$MULTIBLEU $TGT_TEST.true < $TRAIN_DIR/test.$TGT.hyp.true > $TRAIN_DIR/eval.true
$MULTIBLEU $TGT_TEST.tok < $TRAIN_DIR/test.$TGT.hyp.tok > $TRAIN_DIR/eval.tok
cat $TRAIN_DIR/eval.tok

# Backtranslation

echo "End of training. Experiment is stored in: $TRAIN_DIR"
