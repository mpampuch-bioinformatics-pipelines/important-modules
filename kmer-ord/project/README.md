# README

## 20260714

This is just a temporary Chat-GPT output 

Also the test is also chatgpt generated

For the test, run it with the real read files


## 20260715

Get initial working version of kmer-ord project workflow in nextflow:

- still need to test if will work on gpu
- the module may not work on FASTQ files
- still want to add a third field to the samplesheet that will be called  or something that will run the pipeline multiple times across kmer_sizes

## 20260719

- Actually, this module doesn't require any GPU acceleration because the current version of Tiara doesn't expose GPUs to the user when doing classification. Everything is run on CPU (inspect the source code here: https://github.com/ibe-uw/tiara)
  

