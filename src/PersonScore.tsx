import React,{ useEffect , useState} from "react";
import { getPerson } from "./getPerson";

export function PersonScore() {
    const [name,setName] = useState <String|undefined>();
    const [score,setScore] = useState (0);
    const [loading,setLoading] = useState(true);



  useEffect(() => {
    getPerson().then((person) => {
    setLoading(false);
    setName(person.name); 
   });

  }, []);


  if (loading)
  {
    return <div>Loading...</div>;
  }
  return (
    <div>
    <h1>Hello, {name}!</h1>
    <p>Your score is best one {score}</p>
  


    <button onClick = {()=>setScore(score+1)}>Add</button>
    <button onClick ={()=>setScore(score-1)}>Subtract</button>
    <button onClick ={()=>setScore(0)}>Reset</button>
    </div>
  )

  
};