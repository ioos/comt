A.  Test your NcML before you put it in the Google Doc.

1. Go to:  http://testbedapps.sura.org/thredds/catalog.html
2.  Choose "All Uploaded Datasets"
3. Navigate the directory tree (Inundation=>vims=>selfe_tropical=>
etc) until you get get to the directory with the NcML file.
4.  click on the NcML file, which opens a page like this:
example: <http://testbedapps.sura.org/thredds/catalog/alldata/Inundation/vims/selfe_tropical/runs/Ike/2D_varied_manning_windstress/catalog.html?dataset=alldata/Inundation/vims/selfe_tropical/runs/Ike/2D_varied_manning_windstress/04_dir.ncml>
5. click on the OPeNDAP link, which opens the OPeNDAP Data Access Form.
example: http://testbedapps.sura.org/thredds/dodsC/alldata/Inundation/vims/selfe_tropical/runs/Ike/2D_varied_manning_windstress/04_dir.ncml.html
6. copy the Data URL you find on that form.   Example:
http://testbedapps.sura.org/thredds/dodsC/alldata/Inundation/vims/selfe_tropical/runs/Ike/2D_varied_manning_windstress/04_dir.ncml
7. In Matlab, open that OPeNDAP Data URL using the NCTOOLBOX  "ncgeodataset"
example:
url = 'http://testbedapps.sura.org/thredds/dodsC/alldata/Inundation/vims/selfe_tropical/runs/Ike/2D_varied_manning_windstress/04_dir.ncml'
nc = ncgeodataset(url)
nc.variables

B. Add the dataset to the Google Doc:
https://docs.google.com/spreadsheet/ccc?key=0AjAHlPEEP_ujdHJLaENFYTRGVmw5U0RfMWhuWXNqRkE#gid=0

C. A new inundation catalog is generated from the Google Doc every
hour (3:00, 4:00, etc), which makes the datasets available at:
<http://testbedapps-dev.sura.org/thredds/inundation.html>.   This is
where people are supposed to access the data, not directly from the
NcML as in Step A.

In the near future, when we get out of the development phase, the
datasets will appear at
http://testbedapps.sura.org/thredds/inundation.html

If you use this catalog to navigate to the OPeNDAP Data URL, you can
access this the same way in Matlab.  Example:

url = 'http://testbedapps-dev.sura.org/thredds/dodsC/in/vims/selfe/ike/ultralite/vardrag/nowave/2d'
nc = ncgeodataset(url)
nc.variables