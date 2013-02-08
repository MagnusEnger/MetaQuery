MetaQuery by Libriotech

This is a proof of concept of a highly configurable front end WebGUI for 
semantic data. 

* Logic:

Start with a URI
Find the Type of the URI
Find the TypeTemplate for the Type
Find the DataPoints for the Type
DataPoints have a Slug, a (SPARQL) Query and a Template
Loop over all the DataPoints
Collect the Data from the Query (with the original URI as a possible parameter)
Save the Data in a Hash Of Hashes, with the Slug as key and Data and Template as values
Evaluate the TypeTemplate with the Hash Of Hashes as data

* Demo

A demo is available here: http://metaquery.libriotech.no/
It uses this triplestore: http://data.libriotech.no/metaquery/
The data in the triplestore is also available here: 
http://data.libriotech.no/metaquery/data.txt

* Questions? Comments? 

magnus@libriotech.no

* License

See the included LICENSE file.
