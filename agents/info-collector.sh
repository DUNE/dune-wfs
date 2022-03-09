#!/bin/sh
#
# Collect information to put in the Workflow Database
#
# This will be rewritten in Python with better error recoverye etc
#

. /usr/lib/python3.6/site-packages/wfs/conf.py

#
# Make sure all RSEs known to Rucio are in the database
#

rucio list-rses | (

while read rse
do
  # Do an INSERT in case this is a new RSE; fails silently if not new
  mysql -u $mysqlUser -p$mysqlPassword \
        -e "INSERT IGNORE INTO storages SET rse_name='$rse'" wfdb
done

)

mysql -u $mysqlUser -p$mysqlPassword \
      -e "INSERT IGNORE INTO storages SET rse_name='MONTECARLO',occupancy=1" wfdb

#
# Make sure all the sites have storage mappings in the database
#

# Use DUNE VO Feed to get a list of DUNESite names for all sites in CRIC / OSG Pilot Factories
curl --capath /etc/grid-security/certificates/ https://dune-cric.cern.ch/api/dune/vofeed/list/ | sed 's/</\
/g' | grep 'type="DUNE_Site"' | cut -d'"' -f2 >/tmp/info-collector.sites.txt

mysql -u $mysqlUser -p$mysqlPassword -N -B \
      -e 'SELECT rse_id,rse_name FROM storages' wfdb | (

while read rse_id rse_name
do
  rse_prefix=`echo "$rse_name" | cut -f1 -d_`

  for site_name in `cat /tmp/info-collector.sites.txt`
  do
    # Nasty hard coding of samesite storage mappings for now
    if [ "$site_name" = 'US_FNAL' -a "$rse_prefix" = 'FNAL' ] ; then
      location='samesite'  
    elif [ "$site_name" = 'CERN' -a "$rse_prefix" = 'CERN' ] ; then
      location='samesite'  
    elif [ "$site_name" = 'UK_Manchester' -a "$rse_name" = 'MANCHESTER' ] ; then
      location='samesite'  
    elif [ "$site_name" = 'UK_RAL-Tier1' -a "$rse_name" = 'RAL_ECHO' ] ; then
      location='samesite'
    elif [ "$site_name" = 'UK_RAL-PPD' -a "$rse_name" = 'RAL_ECHO' ] ; then
      location='nearby'  
    else
      # Everywhere else is accessible at least, for now
      location='accessible'
    fi
    
    mysql -u $mysqlUser -p$mysqlPassword \
          -e "REPLACE INTO sites_storages SET rse_id=$rse_id,site_name='$site_name',location='$location'" wfdb
    
  done
  
done
)

# CERN_PDUNE_CASTOR is not even accessible from any site
mysql -u $mysqlUser -p$mysqlPassword -N -B \
      -e 'DELETE FROM sites_storages WHERE rse_id=(SELECT rse_id FROM storages WHERE rse_name="CERN_PDUNE_CASTOR")' \
      wfdb
