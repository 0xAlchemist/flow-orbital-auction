const express = require('express')
const app = express()
const port = 3000

app.get('/payouts/:number', (req, res) => {
    res.json(getWeights( Number(req.params.number)));  
})

app.listen(port, () => {
    console.log(`Example app listening at http://localhost:${port}`)
})

// returns array of payout weights for specific epoch  
function getWeights(n) { 
    var array = []
    var sum = sumOfFactors(n)
    for(var y=1; y< n+1; y++) {
      if (n%y === 0) // if divisible with no remainder 
        array.push(  {token: y, weight: y/sum } );
    }
    return array;
}
  
  function sumOfFactors(n) 
  { 
      // Traversing through all prime factors. 
      var res = 1; 
      for (var i = 2; i <= Math.sqrt(n); i++) 
      {     
          var curr_sum = 1; 
          var curr_term = 1; 
          while (n % i == 0) { 
    
              n = n / i; 
    
              curr_term *= i; 
              curr_sum += curr_term; 
          } 
    
          res *= curr_sum; 
      } 
    
      // This condition is to handle  
      // the case when n is a prime 
      // number greater than 2. 
      if (n >= 2) 
          res *= (1 + n); 
    
      return res; 
}
