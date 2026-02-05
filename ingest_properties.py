import pandas as pd
from langchain_text_splitters import RecursiveCharacterTextSplitter
from langchain_community.vectorstores import FAISS
from langchain_community.embeddings import HuggingFaceEmbeddings
from langchain_core.documents import Document


def row_to_text(row):
    return "\n".join([f"{col}: {row[col]}" for col in row.index])


def ingest():
    # Load CSV
    df = pd.read_csv("data/properties.csv")

    # Convert rows to documents
    docs_raw = []
    for _, row in df.iterrows():
        text = row_to_text(row)
        docs_raw.append(Document(page_content=text))

    # Split documents
    splitter = RecursiveCharacterTextSplitter(
        chunk_size=500,
        chunk_overlap=50
    )

    docs = splitter.split_documents(docs_raw)

    # Embeddings (same as reference)
    embeddings = HuggingFaceEmbeddings(
        model_name="sentence-transformers/all-MiniLM-L6-v2"
    )

    # Store in FAISS
    vector_db = FAISS.from_documents(docs, embeddings)
    vector_db.save_local("faiss_index")

    print("✅ Property embeddings created successfully.")


if __name__ == "__main__":
    ingest()
