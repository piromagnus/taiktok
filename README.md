# Tiktok like app for AI papers
The idea is to be addicted to read AI papers instead of scrolling on tiktok.


# Improvements
- Make the PaperService a provider ? 
- Get at the start all the papersID + embedding
- Compute the similarity with the query everytimes it is changed.
- keep a map flow {arxvID : similary } in PaperService that will be update with new paper from arxiv
- remove the read papers from the main map, update also the backend  (removing the read one.)
- Everytime the front ask for more Papers, it just find the X best one from the Map and call the API + checkEverystuff are there



# Weird implementation

- _loadAllPaperIds doesn't take readPapers. So it loads everything