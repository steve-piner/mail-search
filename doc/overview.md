# A structural overview

## Indexing

Extract

Returns a complete mail message. May include some metadata

Return { message => '...' }

Transform

Take a mail message and convert it into fields and text

Return { 'text' => '...', 'metadata' => { 'field' => '...', 'multivalued field' => [...] } }

Load

Load the transformed data into the search engine

## Web site

..
