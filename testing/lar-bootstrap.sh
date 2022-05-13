#!/bin/sh
#
# Example bootstrap script that runs lar  of all the files
# referred to by the MQL expression give on the workflow command line.
#
# Submit with something like this:
#
# ./workflow quick-request \
#  --max-distance 30 \
#  --mql "rucio-dataset protodune-sp:np04_raw_run_number_5769" \
#  --file lar-bootstrap.sh 
#
# Then monitor with dashboard or ./workflow show-jobs --request-id ID
# where ID is the value printed by the first command
#

# From jobsub
export CLUSTER=${CLUSTER:-1}
export PROCESS=${PROCESS:-1}

# Get an unprocessed file from this stage
did_pfn_rse=`$WFS_PATH/wfs-get-file`
did=`echo $did_pfn_rse | cut -f1 -d' '`
pfn=`echo $did_pfn_rse | cut -f2 -d' '`
rse=`echo $did_pfn_rse | cut -f3 -d' '`

. /cvmfs/fermilab.opensciencegrid.org/products/common/etc/setups
export FILETIMESTAMP=$(date -u +%Y%m%dT%H%M%SZ)
source /cvmfs/dune.opensciencegrid.org/products/dune/setup_dune.sh
setup dunetpc v09_09_01 -q e19:prof
setup protoduneana v09_09_01 -q e19:prof
setup duneutil v09_09_01_01 -q e19:prof
setup dune_oslibs v1_0_0

echo "Found input file URL $pfn at $rse"

sed \
 -e "s/\"DUNE_CERN_SEP2018\"/\"DUNE_CERN_SEP2018_ANALYSIS\"/" \
 ${DUNETPC_DIR}/job/BeamEvent.fcl > ./BeamEvent.fcl

lar --nevts 3 \
    -c protoDUNE_SP_keepup_decoder_reco_stage1.fcl \
    -o %ifb_reco1_${CLUSTER}_${PROCESS}_${FILETIMESTAMP}.root \
    $pfn

lar -c michelremoving.fcl -s *_reco1_${CLUSTER}_${PROCESS}_${FILETIMESTAMP}.root

cp ${JSB_TMP}/JOBSUB_LOG_FILE \
 ./PDSPProd2-goodruns6GeVc_slice_423582_stage_2000_${CLUSTER}_${PROCESS}.out
cp ${JSB_TMP}/JOBSUB_ERR_FILE \
 ./PDSPProd2-goodruns6GeVc_slice_423582_stage_2000_${CLUSTER}_${PROCESS}.err

extractor_prod.py \
 --infile $(ls *reco1_${CLUSTER}_${PROCESS}_${FILETIMESTAMP}.root) \
 --appfamily art --appname reco --appversion v09_09_01 \
 --campaign WFATest1 --no_crc --data_stream physics \
 > $(ls *_reco1_${CLUSTER}_${PROCESS}_${FILETIMESTAMP}.root).json

mv michelremoving.root \
  $(ls *reco1_${CLUSTER}_${PROCESS}_${FILETIMESTAMP}.root \
  | sed -e "s/\.root/_michelremoving.root/")

mv Pandora_Events.pndr \
  $(ls *reco1_${CLUSTER}_${PROCESS}_${FILETIMESTAMP}.root \
  | sed -e "s/\.root/_Pandora_Events\.pndr/")

mv $(ls hist_*reco.root) \
  $(ls hist_*_reco.root | sed -e "s/\.root/_${CLUSTER}_${PROCESS}_${FILETIMESTAMP}\.root/")

pandora_metadata.py \
 --infile $(ls *_Pandora_Events.pndr)  \
 --appfamily art --appname reco \
 --appversion v09_09_01 --campaign WFATest1 --no_crc --data_stream physics \
 --input_json $(ls *_reco1_${CLUSTER}_${PROCESS}_${FILETIMESTAMP}.root.json) \
 > $(ls *_Pandora_Events.pndr).json

pandora_metadata.py \
 --infile $(ls *_michelremoving.root)  \
 --appfamily art --appname calana --appversion v09_09_01 --campaign WFATest1 \
 --no_crc --data_stream physics \
 --input_json $(ls *_reco1_${CLUSTER}_${PROCESS}_${FILETIMESTAMP}.root.json) \
 --data_tier root-tuple --file_format rootntuple --strip_parents \
 > $(ls *_michelremoving.root).json

sed -i -e "/file_name/ a     \"parents\": [\"$(ls *reco1_${CLUSTER}_${PROCESS}_${FILETIMESTAMP}.root)\"]," $(ls *_michelremoving.root).json

# Record that we processed the input file ok (did we???)
echo "$pfn" >> wfa-processed-pfns.txt
touch wfa-unprocessed-pfns.txt

# Patterns to put in stage outputs definition:
# np04*_reco*Z.root *_Pandora_Events.pndr *_michelremoving.root

# For debugging
for i in *.json
do
  echo "==== Start $i ===="
  cat $i
  echo "==== End $i ===="
done

ls -ltR

exit 0
