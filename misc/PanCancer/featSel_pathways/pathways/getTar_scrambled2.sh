#!/bin/bash
# run on mac, remotely tarballs results and downloads
# KIRC pathway predictor

VM1=spai@192.168.81.125
VM3=spai@192.168.81.249
VM4=netdx@192.168.81.206
VM5=spai@192.168.81.122
DELL=shraddhapai@192.168.81.215

localDir=/Users/shraddhapai/DropBox/netDx/BaderLab/2017_TCGA_KIRC/output/scrambled2_170810
mkdir $localDir

# DELL
indir=/home/shraddhapai/BaderLab/PanCancer_KIRC/output/pathwaysScramble_170810
outF=scrambled2_Dell_170810.tar.gz
ssh $DELL "cd $indir; tar cvfz ~/${outF} rng*/predictionResults.txt rng*/SURVIVE*/*/*CV_score.txt" 
scp $DELL:~/${outF} .

# DELL2
indir=/home/shraddhapai/BaderLab/PanCancer_KIRC/output/pathwaysScramble2_170810
outF=scrambled2_Dell2_170810.tar.gz
ssh $DELL "cd $indir; tar cvfz ~/${outF} rng*/predictionResults.txt rng*/SURVIVE*/*/*CV_score.txt" 
scp $DELL:~/${outF} .

# VM1
indir=/mnt/data2/BaderLab/PanCancer_KIRC/output/pathwaysScramble_170810
outF=scrambled2_VM1_170810.tar.gz
ssh $VM1 "cd $indir; tar cvfz ~/${outF} rng*/predictionResults.txt rng*/SURVIVE*/*/*CV_score.txt" 
scp $VM1:~/${outF} .

# VM3
indir=/home/spai/BaderLab/PanCancer_KIRC/output/pathwaysScramble_170810
outF=scrambled2_VM3_170810.tar.gz
ssh $VM3 "cd $indir; tar cvfz ~/${outF} rng*/predictionResults.txt rng*/SURVIVE*/*/*CV_score.txt" 
scp $VM3:~/${outF} .

# VM4
indir=/home/netdx/BaderLab/PanCancer_KIRC/output/pathwaysScramble_170810
outF=scrambled2_VM4_170810.tar.gz
ssh $VM4 "cd $indir; tar cvfz ~/${outF} rng*/predictionResults.txt rng*/SURVIVE*/*/*CV_score.txt" 
scp $VM4:~/${outF} .

mv *gz ${localDir}/.
cd $localDir
tar xvfz scrambled2_VM1_170810.tar.gz
tar xvfz scrambled2_VM3_170810.tar.gz
tar xvfz scrambled2_VM4_170810.tar.gz
tar xvfz scrambled2_Dell2_170810.tar.gz
tar xvfz scrambled2_Dell_170810.tar.gz