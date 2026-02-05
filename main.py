from dotenv import load_dotenv
load_dotenv()
from fastapi import FastAPI
from pydantic import BaseModel
from qa import ask


app = FastAPI(title="Property AI Assistant")

class Query(BaseModel):
    question: str

@app.post("/chat")
def chat(query: Query):
    answer = ask(query.question)
    return {"answer": answer}
