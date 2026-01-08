+++
title = "    # The Reranker: RAG's Secret Weapon"
date = 2025-11-29
description = "Boost RAG accuracy with rerankers. Learn how reranking improves retrieval quality by reordering vector search results before LLM generation."
summary = "Your RAG retrieves 10 documents but the right answer is in position 7 - and the LLM only looks at the top 3. Rerankers fix this by scoring each document against the actual query and reordering results before the LLM sees them. A simple second-stage filter that dramatically improves accuracy without changing your embedding model."
image = "images/agent-neon-05.webp"
draft = false
tags = ['rag', 'patterns', 'deep-dive']
voice = false
+++


    Your RAG retrieves 10 documents. The right answer is in position 7.

    The LLM never sees it. It only looks at the top 3.

    Wrong answer. User frustrated.

    The fix? Rerank before you generate.

    ## The retrieval problem

    Vector search is fast but imprecise.

    ```
    Query: "How do I reset my password?"

    Top 5 by embedding similarity:
    1. "Password security best practices" (0.89)     ← wrong
    2. "Account settings overview" (0.87)            ← wrong
    3. "Reset password via email link" (0.85)        ← RIGHT
    4. "Two-factor authentication setup" (0.84)      ← wrong
    5. "Password requirements" (0.83)                ← wrong
    ```

    The right document is #3, but the scores are so close that noise pushes irrelevant docs higher.

    When you only pass top 3 to the LLM, you miss the answer.

    ## What is reranking?

    Reranking is a second pass. It takes your initial results and re-scores them more carefully.

    ```
    Step 1: Fast retrieval (vector search)
            Query → Top 20 candidates (fast, imprecise)

    Step 2: Rerank (cross-encoder)
            Query + each candidate → new score (slow, precise)

    Step 3: Use top results
            Top 3 after reranking → LLM
    ```

    Think of it like this:
    - **Retrieval**: Quickly grab anything that might be relevant
    - **Reranking**: Carefully score each candidate

    ## Why reranking works better

    ### Bi-encoder (embedding search)

    ```
    Query:    "reset password" → [0.2, 0.5, 0.1, ...]
    Document: "Reset password via email" → [0.3, 0.4, 0.2, ...]

    Score = cosine_similarity(query_vec, doc_vec) = 0.85
    ```

    The query and document are encoded **separately**. They never "see" each other.

    ### Cross-encoder (reranker)

    ```
    Input: "[Query] reset password [SEP] Reset password via email link"

    Model processes query AND document together.

    Score = 0.94
    ```

    The model sees both at once. It can understand:
    - Does this document actually answer the query?
    - Are the keywords in the right context?
    - Is this a direct answer or tangentially related?

    Cross-encoders are more accurate because they compare directly.

    ## The accuracy difference

    Same query, same documents:

    ```
    Query: "How do I cancel my subscription?"

    Bi-encoder (embedding) ranking:
    1. "Subscription plans and pricing" (0.91)
    2. "Cancel subscription in account settings" (0.89)
    3. "Subscription FAQ" (0.88)
    4. "Billing and payments" (0.87)

    Cross-encoder (reranker) ranking:
    1. "Cancel subscription in account settings" (0.97)
    2. "Subscription FAQ" (0.72)
    3. "Subscription plans and pricing" (0.31)
    4. "Billing and payments" (0.28)
    ```

    The reranker immediately identifies the direct answer. The embedding search thought "plans and pricing" was most relevant because it shares vocabulary.

    ## Implementation

    ### Using Cohere Rerank

    ```python
    import cohere

    co = cohere.Client("your-api-key")

    def rerank(query: str, documents: list, top_n: int = 3) -> list:
        """Rerank documents using Cohere"""
        response = co.rerank(
            model="rerank-english-v3.0",
            query=query,
            documents=documents,
            top_n=top_n
        )

        return [
            {
                "text": documents[r.index],
                "score": r.relevance_score,
                "original_index": r.index
            }
            for r in response.results
        ]

    # Usage
    query = "How do I reset my password?"
    candidates = [
        "Password security best practices for your account",
        "Account settings and preferences overview",
        "Reset your password using the email link we send you",
        "Setting up two-factor authentication",
        "Password requirements: 8+ characters, one number"
    ]

    results = rerank(query, candidates, top_n=3)
    # [
    #   {"text": "Reset your password using the email link...", "score": 0.97},
    #   {"text": "Account settings and preferences overview", "score": 0.42},
    #   {"text": "Password requirements: 8+ characters...", "score": 0.38}
    # ]
    ```

    ### Using sentence-transformers (free, local)

    ```python
    from sentence_transformers import CrossEncoder

    # Load model (runs locally)
    reranker = CrossEncoder('cross-encoder/ms-marco-MiniLM-L-6-v2')

    def rerank(query: str, documents: list, top_n: int = 3) -> list:
        """Rerank using local cross-encoder"""
        # Create query-document pairs
        pairs = [[query, doc] for doc in documents]

        # Score all pairs
        scores = reranker.predict(pairs)

        # Sort by score
        scored_docs = list(zip(documents, scores))
        scored_docs.sort(key=lambda x: x[1], reverse=True)

        return [
            {"text": doc, "score": float(score)}
            for doc, score in scored_docs[:top_n]
        ]
    ```

    ### Using Voyage AI

    ```python
    import voyageai

    vo = voyageai.Client()

    def rerank(query: str, documents: list, top_n: int = 3) -> list:
        response = vo.rerank(
            query=query,
            documents=documents,
            model="rerank-2",
            top_k=top_n
        )

        return [
            {"text": r.document, "score": r.relevance_score}
            for r in response.results
        ]
    ```

    ## Full RAG pipeline with reranking

    ```python
    class RAGWithReranking:
        def __init__(self, vector_store, reranker, llm):
            self.vector_store = vector_store
            self.reranker = reranker
            self.llm = llm

        def query(self, question: str) -> str:
            # Step 1: Initial retrieval (get many candidates)
            candidates = self.vector_store.search(
                question,
                top_k=20  # Retrieve more than we need
            )

            # Step 2: Rerank
            reranked = self.reranker.rerank(
                query=question,
                documents=[c["text"] for c in candidates],
                top_n=5  # Keep best 5
            )

            # Step 3: Generate answer
            context = "\n\n".join([r["text"] for r in reranked])

            response = self.llm.create(
                messages=[
                    {"role": "system", "content": f"Context:\n{context}"},
                    {"role": "user", "content": question}
                ]
            )

            return response.content
    ```

    ## How many to retrieve vs rerank?

    The pattern: retrieve many, rerank few.

    ```
    Retrieval: Get top 20-50 candidates (fast)
    Reranking: Score all 20-50, keep top 3-5 (slower but accurate)
    ```

    Why?
    - Vector search misses some relevant docs in top 5
    - But relevant docs are usually somewhere in top 20-50
    - Reranking finds them and promotes them

    ```python
    # Good pattern
    candidates = vector_search(query, top_k=30)  # Cast wide net
    results = rerank(query, candidates, top_n=5)  # Pick best

    # Bad pattern
    candidates = vector_search(query, top_k=5)   # Too narrow
    results = rerank(query, candidates, top_n=3)  # Can't fix bad retrieval
    ```

    ## The latency trade-off

    Reranking adds latency:

    ```
    Without reranking:
    Vector search: 50ms
    Total: 50ms

    With reranking:
    Vector search: 50ms
    Rerank 20 docs: 100-300ms
    Total: 150-350ms
    ```

    But the accuracy gain is usually worth it:

    ```
    Without reranking: 70% of queries get good context
    With reranking: 90% of queries get good context

    User waits extra 200ms, but gets right answer more often.
    ```

    ## Cost comparison

    | Reranker | Cost | Latency | Accuracy |
    |----------|------|---------|----------|
    | Cohere rerank-v3 | $2/1000 queries | ~100ms | Excellent |
    | Voyage rerank-2 | $0.05/1000 queries | ~150ms | Very good |
    | Local cross-encoder | Free | 50-200ms* | Good |
    | No reranking | Free | 0ms | Baseline |

    *Depends on hardware

    ## When to use reranking

    ### Use reranking when:

    **Precision matters more than speed**
    ```
    - Customer support (right answer = happy customer)
    - Legal/compliance (wrong answer = liability)
    - Technical docs (wrong answer = broken code)
    ```

    **Initial retrieval quality is inconsistent**
    ```
    - Vector search returns "close but wrong" results
    - Top 1 result is wrong, but top 5 has the answer
    - Vocabulary overlap causes bad rankings
    ```

    **You have diverse document types**
    ```
    - FAQs + technical docs + blog posts
    - Different writing styles confuse embeddings
    - Reranker normalizes across types
    ```

    ### Skip reranking when:

    **Speed is critical**
    ```
    - Real-time autocomplete
    - Sub-100ms requirements
    ```

    **Initial retrieval is already good**
    ```
    - Highly structured data
    - Unique keywords per document
    - Full-text search already works
    ```

    **Budget is extremely tight**
    ```
    - API rerankers cost per query
    - Local models need compute
    ```

    ## Reranking strategies

    ### Strategy 1: Always rerank

    ```python
    def search(query):
        candidates = vector_search(query, top_k=20)
        return rerank(query, candidates, top_n=5)
    ```

    Simple. Consistent. Higher latency.

    ### Strategy 2: Conditional reranking

    ```python
    def search(query):
        candidates = vector_search(query, top_k=10)

        # Only rerank if top results are too similar
        score_spread = candidates[0]["score"] - candidates[4]["score"]

        if score_spread < 0.1:  # Scores are clustered
            return rerank(query, candidates, top_n=5)
        else:
            return candidates[:5]  # Top result is clear winner
    ```

    Saves latency when retrieval is confident.

    ### Strategy 3: Two-stage for high-stakes

    ```python
    def search(query, high_stakes=False):
        candidates = vector_search(query, top_k=50 if high_stakes else 20)

        if high_stakes:
            # Double rerank: coarse then fine
            stage1 = rerank_fast(query, candidates, top_n=10)
            stage2 = rerank_accurate(query, stage1, top_n=3)
            return stage2
        else:
            return rerank(query, candidates, top_n=5)
    ```

    More compute for important queries.

    ## Debugging reranking

    ### Log everything

    ```python
    def search_with_logging(query: str) -> dict:
        # Initial retrieval
        candidates = vector_search(query, top_k=20)

        # Rerank
        reranked = rerank(query, [c["text"] for c in candidates], top_n=5)

        # Log for debugging
        log = {
            "query": query,
            "initial_top_3": [
                {"text": c["text"][:100], "score": c["score"]}
                for c in candidates[:3]
            ],
            "reranked_top_3": [
                {"text": r["text"][:100], "score": r["score"]}
                for r in reranked[:3]
            ],
            "position_changes": [
                candidates.index(next(c for c in candidates if c["text"] == r["text"]))
                for r in reranked[:3]
            ]
        }

        print(f"Query: {query}")
        print(f"Top result moved from position {log['position_changes'][0] + 1} to 1")

        return reranked
    ```

    ### Watch for:

    ```
    Red flags:
    - Reranker always agrees with retrieval (maybe not helping)
    - Reranker always disagrees (maybe misconfigured)
    - Big latency spikes (too many candidates)

    Good signs:
    - Top result changes 30-50% of the time
    - Accuracy improves measurably
    - User feedback improves
    ```

    ## Implementation with Gantz

    Using [Gantz](https://gantz.run) with reranking:

    ```yaml
    # gantz.yaml
    tools:
    - name: search_docs
        description: Search documentation with high accuracy
        parameters:
        - name: query
            type: string
            required: true
        script:
        shell: |
            # Get candidates from vector store
            candidates=$(curl -s "http://vector-db:8000/search?q={{query}}&top_k=20")

            # Rerank via API
            reranked=$(echo "$candidates" | curl -s -X POST \
            "http://reranker:8000/rerank" \
            -H "Content-Type: application/json" \
            -d "{\"query\": \"{{query}}\", \"documents\": $candidates, \"top_n\": 5}")

            echo "$reranked"
    ```

    Or with Python tools:

    ```yaml
    tools:
    - name: search_docs
        description: Search documentation with reranking
        parameters:
        - name: query
            type: string
            required: true
        script:
        python: |
            from rag import RAGWithReranking
            rag = RAGWithReranking()
            results = rag.search("{{query}}")
            print(results)
    ```

    ## Quick start

    ### 1. Install

    ```bash
    pip install cohere
    # or
    pip install sentence-transformers
    ```

    ### 2. Add reranking to existing RAG

    ```python
    import cohere
    co = cohere.Client("your-key")

    # Your existing RAG
    def rag_query(question):
        # Existing: get top 5
        # candidates = vector_search(question, top_k=5)

        # New: get top 20, rerank to top 5
        candidates = vector_search(question, top_k=20)
        texts = [c["text"] for c in candidates]

        reranked = co.rerank(
            query=question,
            documents=texts,
            model="rerank-english-v3.0",
            top_n=5
        )

        context = "\n".join([texts[r.index] for r in reranked.results])
        return generate_answer(question, context)
    ```

    ### 3. Measure improvement

    ```python
    # Before reranking
    accuracy_before = evaluate_rag(test_questions)  # e.g., 72%

    # After reranking
    accuracy_after = evaluate_rag_with_reranking(test_questions)  # e.g., 89%

    print(f"Improvement: {accuracy_after - accuracy_before}%")  # +17%
    ```

    ## Summary

    Reranking in one sentence: **Retrieve many, score carefully, keep best.**

    | Stage | What it does | Speed | Accuracy |
    |-------|--------------|-------|----------|
    | Retrieval | Get candidates | Fast | Okay |
    | Reranking | Score candidates | Slower | Great |
    | Combined | Best of both | Medium | Great |

    When to add reranking:
    - Your RAG returns "close but wrong" results
    - Top 5 often has the right answer buried at position 4-5
    - Users complain about bad answers
    - Accuracy matters more than 100ms latency

    The best RAG pipelines always rerank.

## Related reading

- [RAG Is Overrated for Most Use Cases](/post/rag-overrated/) - When you don't need RAG at all
- [Full-Text Search: The RAG Alternative Nobody Tries](/post/fulltext-search/) - Simpler search solutions
- [Tool Use vs RAG: When to Retrieve, When to Act](/post/tool-use-vs-rag/) - Choosing the right approach

    ---

    *Have you added reranking to your RAG? What improvement did you see?*
