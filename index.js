const express = require('express');
const path = require('path');
const app = express();

app.use(express.static(path.join(__dirname, '/')));

app.all('/', (req, res) => {
  res.send(`flarial cdn trolololololol`)
})

app.listen(5000, () => {
  console.log("Server is Ready!!" + Date.now())
});
