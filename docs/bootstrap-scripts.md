## Bootstrap scripts

The bootstrap scripts supplied when creating a stage are shell scripts 
which the generic jobs execute on the worker nodes matched to that stage.  
They are started in an empty workspace directory.  Several environment 
variables are made available to the scripts, all prefixed with WFS_, 
including $WFS_REQUEST_ID, $WFS_STAGE_ID and $WFS_COOKIE which allows the 
bootstrap script to authenticate to the 
[Workflow Allocator](workflow-allocator.md). $WFS_PATH is 
used to reference files and scripts provided by the Workflow System.

To get the details of an input file to work on, the command 
$WFS_PATH/wfs-get-file is executed by the bootstrap script.  This produces 
a single line of output with the Rucio DID of the chosen file, its PFN on 
the optimal RSE, and the name of that RSE, all separated by spaces. This 
code fragment shows how the DID, PFN and RSE can be put into shell 
variables:

```
did_pfn_rse=`$WFS_PATH/wfs-get-file`
did=`echo $did_pfn_rse | cut -f1 -d' '`
pfn=`echo $did_pfn_rse | cut -f2 -d' '`
rse=`echo $did_pfn_rse | cut -f3 -d' '`
```

If no file is available to be processed, then wfs-get-file produces no 
output to stdout, which should also be checked for.  wfs-get-file logs 
errors to stderr.

wfs-get-file can be called multiple times to process more than one file in 
the same bootstrap script. This can be done all at the start or repeatedly 
during the lifetime of the job. wfs-get-file is itself a simple wrapper 
around the curl command and it would also be possible to access the 
Workflow Allocator's REST API directly from an application.

Each file returned by wfs-get-file is marked as allocated and will not be 
processed by any other jobs. When the bootstrap script finishes, it must 
leave files with lists of the processed and unprocessed files in its 
workspace directory. These lists are sent to the Workflow Allocator by the 
generic job, which either marks input files as being successfully 
processed or resets their state to unallocated, ready for matching by 
another job.

Files can be referred to either by DID or PFN, one  per  line,  in  the
appropriate list file:
```
wfs-processed-dids.txt
wfs-processed-pfns.txt
wfs-unprocessed-dids.txt
wfs-unprocessed-pfns.txt
```

It is not necessary to create list files which would otherwise be empty. 
You can use a mix of DIDs and PFNs, as long as each appears in the correct 
list file.

Output files which are to be uploaded with Rucio by the generic job must 
be created in the bootstrap's workspace directory and have filenames 
matching the patterns given by --output-pattern or 
--output-pattern-next-stage when the stage was created.  The suffixed 
.json is appended to find the corresponding metadata files for MetaCat.
