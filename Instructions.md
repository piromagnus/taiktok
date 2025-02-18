# Taiktok
## General idea 
an tiktok like app for new AI paper reading

# Theme
ethereal; science-fictionnal theme

# Features
- A doom scroller with 1 paper at a time with the title and with a tap you get a new information about the paper like a carousel
- A automatic scrap on arxiv to find the recent papers based on possible custom query
- A storage on firebase/firestore that will save all the papers queried on arxiv. The storage will be updated automatically when a new paper is found ie when the use has read all the papers in the database
- A like with a double tap that will be stored on firebase/firestore and will be used to mark the paper as liked for each use.
- there will be 2 database : 1 for the storage of all papers and one for each user with the id of the papers read and a bool for like and time spent on it.
- You will collect the time spent to read each papers.
- On the last page you will add the link to be open directly with a new instance of the app to arxiv with a built-in navigator and pdf reader
- 


# Next steps
- Store in Firebase
- Use a embedding to find similar papers in the database with respect to the query
- Add a chatbot to the app to ask question about the paper