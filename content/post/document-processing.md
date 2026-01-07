+++
title = "PDF to Structured Data: AI Document Processing"
image = "/images/document-processing.png"
date = 2025-11-13
description = "Build an AI agent that extracts structured data from PDFs, invoices, contracts, and forms. Convert unstructured documents to JSON using MCP tools."
draft = false
tags = ['mcp', 'tutorial', 'document-processing']
voice = false

[howto]
name = "Build Document Processor"
totalTime = 35
[[howto.steps]]
name = "Create extraction tools"
text = "Build MCP tools for PDF parsing and OCR."
[[howto.steps]]
name = "Design extraction schemas"
text = "Define data structures for different document types."
[[howto.steps]]
name = "Implement extraction logic"
text = "Build the agent that extracts structured data."
[[howto.steps]]
name = "Add validation"
text = "Validate extracted data against schemas."
[[howto.steps]]
name = "Build batch processing"
text = "Handle multiple documents efficiently."
+++


PDFs everywhere. Data trapped inside.

Invoices. Contracts. Forms. Reports.

AI can extract it all into structured data.

## The document problem

Every business deals with:
- Invoices from different vendors
- Contracts in various formats
- Forms with inconsistent layouts
- Reports that need parsing
- Scanned documents

Manual extraction doesn't scale. AI does.

## What you'll build

- PDF text extraction
- OCR for scanned documents
- Invoice data extraction
- Contract parsing
- Form field extraction
- Batch document processing

## Step 1: Create extraction tools

Using [Gantz](https://gantz.run):

```yaml
# gantz.yaml
name: document-processor

tools:
  - name: extract_pdf_text
    description: Extract text from a PDF file
    parameters:
      - name: file_path
        type: string
        required: true
      - name: pages
        type: string
        description: "Page range (e.g., '1-5' or 'all')"
        default: "all"
    script:
      command: python
      args: ["scripts/extract_pdf.py", "{{file_path}}", "{{pages}}"]

  - name: ocr_document
    description: OCR a scanned document or image
    parameters:
      - name: file_path
        type: string
        required: true
      - name: language
        type: string
        default: "eng"
    script:
      command: python
      args: ["scripts/ocr.py", "{{file_path}}", "{{language}}"]

  - name: get_pdf_metadata
    description: Get PDF metadata (title, author, pages, etc.)
    parameters:
      - name: file_path
        type: string
        required: true
    script:
      command: python
      args: ["scripts/pdf_metadata.py", "{{file_path}}"]

  - name: extract_tables
    description: Extract tables from a document
    parameters:
      - name: file_path
        type: string
        required: true
      - name: page
        type: integer
        default: 1
    script:
      command: python
      args: ["scripts/extract_tables.py", "{{file_path}}", "{{page}}"]

  - name: extract_images
    description: Extract images from a PDF
    parameters:
      - name: file_path
        type: string
        required: true
      - name: output_dir
        type: string
        default: "extracted_images"
    script:
      command: python
      args: ["scripts/extract_images.py", "{{file_path}}", "{{output_dir}}"]

  - name: validate_schema
    description: Validate extracted data against a JSON schema
    parameters:
      - name: data
        type: string
        required: true
      - name: schema_name
        type: string
        required: true
    script:
      command: python
      args: ["scripts/validate.py", "{{schema_name}}"]
      stdin: "{{data}}"

  - name: save_extracted_data
    description: Save extracted data to database
    parameters:
      - name: document_id
        type: string
        required: true
      - name: data
        type: string
        required: true
      - name: document_type
        type: string
        required: true
    script:
      command: python
      args: ["scripts/save_data.py", "{{document_id}}", "{{document_type}}"]
      stdin: "{{data}}"

  - name: list_files
    description: List files in a directory
    parameters:
      - name: path
        type: string
        required: true
      - name: pattern
        type: string
        default: "*.pdf"
    script:
      shell: find "{{path}}" -name "{{pattern}}" -type f
```

PDF extraction script:

```python
# scripts/extract_pdf.py
import sys
import json
import fitz  # PyMuPDF

def extract_text(file_path: str, pages: str = "all") -> dict:
    """Extract text from PDF."""

    doc = fitz.open(file_path)

    # Parse page range
    if pages == "all":
        page_nums = range(len(doc))
    else:
        if "-" in pages:
            start, end = pages.split("-")
            page_nums = range(int(start) - 1, int(end))
        else:
            page_nums = [int(pages) - 1]

    result = {
        "file": file_path,
        "total_pages": len(doc),
        "extracted_pages": [],
        "full_text": ""
    }

    for page_num in page_nums:
        if page_num < len(doc):
            page = doc[page_num]
            text = page.get_text()

            result["extracted_pages"].append({
                "page": page_num + 1,
                "text": text
            })
            result["full_text"] += text + "\n\n"

    doc.close()
    return result

if __name__ == "__main__":
    file_path = sys.argv[1]
    pages = sys.argv[2] if len(sys.argv) > 2 else "all"

    result = extract_text(file_path, pages)
    print(json.dumps(result, indent=2))
```

OCR script:

```python
# scripts/ocr.py
import sys
import json
import pytesseract
from PIL import Image
import fitz
import io

def ocr_document(file_path: str, language: str = "eng") -> dict:
    """OCR a document (PDF or image)."""

    result = {
        "file": file_path,
        "pages": [],
        "full_text": ""
    }

    if file_path.lower().endswith(".pdf"):
        # Convert PDF pages to images and OCR
        doc = fitz.open(file_path)

        for page_num in range(len(doc)):
            page = doc[page_num]
            pix = page.get_pixmap(matrix=fitz.Matrix(2, 2))  # 2x zoom for better OCR
            img = Image.open(io.BytesIO(pix.tobytes()))

            text = pytesseract.image_to_string(img, lang=language)

            result["pages"].append({
                "page": page_num + 1,
                "text": text
            })
            result["full_text"] += text + "\n\n"

        doc.close()
    else:
        # Direct image OCR
        img = Image.open(file_path)
        text = pytesseract.image_to_string(img, lang=language)

        result["pages"].append({"page": 1, "text": text})
        result["full_text"] = text

    return result

if __name__ == "__main__":
    file_path = sys.argv[1]
    language = sys.argv[2] if len(sys.argv) > 2 else "eng"

    result = ocr_document(file_path, language)
    print(json.dumps(result, indent=2))
```

Table extraction:

```python
# scripts/extract_tables.py
import sys
import json
import camelot

def extract_tables(file_path: str, page: int = 1) -> dict:
    """Extract tables from a PDF page."""

    tables = camelot.read_pdf(file_path, pages=str(page))

    result = {
        "file": file_path,
        "page": page,
        "tables": []
    }

    for i, table in enumerate(tables):
        result["tables"].append({
            "table_number": i + 1,
            "accuracy": table.accuracy,
            "data": table.df.to_dict(orient="records"),
            "headers": table.df.columns.tolist()
        })

    return result

if __name__ == "__main__":
    file_path = sys.argv[1]
    page = int(sys.argv[2]) if len(sys.argv) > 2 else 1

    result = extract_tables(file_path, page)
    print(json.dumps(result, indent=2))
```

```bash
gantz run --auth
```

## Step 2: The document processor agent

```python
import anthropic
from typing import Dict, List, Optional
import json

MCP_URL = "https://document-processor.gantz.run/sse"
MCP_TOKEN = "gtz_abc123"

client = anthropic.Anthropic()

EXTRACTION_SYSTEM_PROMPT = """You extract structured data from documents.

Your extractions are:
- Accurate: Match the document exactly
- Complete: Don't miss important fields
- Structured: Follow the provided schema
- Validated: Flag uncertain extractions

For each document:
1. First understand the document type and layout
2. Identify all relevant fields
3. Extract data precisely
4. Note confidence for uncertain fields
5. Validate against expected format

Output format:
- Use JSON for structured data
- Include confidence scores (0-1) for uncertain fields
- Mark missing required fields as null with explanation
- Preserve original formatting where relevant (dates, numbers)"""

def extract_invoice(file_path: str) -> Dict:
    """Extract data from an invoice."""

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=4096,
        system=EXTRACTION_SYSTEM_PROMPT,
        messages=[{
            "role": "user",
            "content": f"""Extract invoice data from: {file_path}

1. Use extract_pdf_text to get the text content
2. If text extraction is poor, use ocr_document
3. Use extract_tables for line items

Extract these fields:
- invoice_number
- invoice_date
- due_date
- vendor_name
- vendor_address
- customer_name
- customer_address
- line_items: [{description, quantity, unit_price, amount}]
- subtotal
- tax_rate
- tax_amount
- total_amount
- payment_terms
- currency

Use validate_schema with schema_name="invoice" to validate.
Output as JSON."""
        }],
        tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
    )

    for content in response.content:
        if hasattr(content, 'text'):
            try:
                return json.loads(content.text)
            except:
                return {"raw": content.text}

    return {}

def extract_contract(file_path: str) -> Dict:
    """Extract key information from a contract."""

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=8192,
        system=EXTRACTION_SYSTEM_PROMPT,
        messages=[{
            "role": "user",
            "content": f"""Extract contract data from: {file_path}

1. Use get_pdf_metadata to understand the document
2. Use extract_pdf_text to get full content
3. Parse and extract:

- contract_type (NDA, MSA, Employment, Lease, etc.)
- effective_date
- expiration_date
- parties: [{name, role, address}]
- key_terms: [list of important terms]
- obligations: [{party, obligation}]
- payment_terms (if applicable)
- termination_clauses
- confidentiality_terms
- intellectual_property_terms
- governing_law
- signatures: [{name, title, date}]

For legal documents, note any unusual clauses or risks.
Output as JSON."""
        }],
        tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
    )

    for content in response.content:
        if hasattr(content, 'text'):
            try:
                return json.loads(content.text)
            except:
                return {"raw": content.text}

    return {}

def extract_form(file_path: str, form_type: str = "generic") -> Dict:
    """Extract data from a filled form."""

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=4096,
        system=EXTRACTION_SYSTEM_PROMPT,
        messages=[{
            "role": "user",
            "content": f"""Extract form data from: {file_path}
Form type: {form_type}

1. Use extract_pdf_text or ocr_document
2. Identify all form fields and their values
3. Handle checkboxes, radio buttons, signatures
4. Note any handwritten content

Output as JSON with:
- field_name: field_value pairs
- checkbox fields as boolean
- date fields in ISO format
- signature fields as "signed" or "not_signed" with signer name if visible

Flag any fields that are unclear or possibly misread."""
        }],
        tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
    )

    for content in response.content:
        if hasattr(content, 'text'):
            try:
                return json.loads(content.text)
            except:
                return {"raw": content.text}

    return {}
```

## Step 3: Specialized extractors

```python
def extract_receipt(file_path: str) -> Dict:
    """Extract data from a receipt."""

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=2048,
        system=EXTRACTION_SYSTEM_PROMPT,
        messages=[{
            "role": "user",
            "content": f"""Extract receipt data from: {file_path}

Receipts often need OCR - use ocr_document if text extraction fails.

Extract:
- store_name
- store_address
- store_phone
- transaction_date
- transaction_time
- items: [{name, quantity, price}]
- subtotal
- tax
- total
- payment_method
- card_last_four (if visible)
- receipt_number

Handle common receipt issues:
- Faded text
- Thermal paper artifacts
- Truncated item names"""
        }],
        tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
    )

    for content in response.content:
        if hasattr(content, 'text'):
            try:
                return json.loads(content.text)
            except:
                return {"raw": content.text}

    return {}

def extract_resume(file_path: str) -> Dict:
    """Extract data from a resume/CV."""

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=4096,
        system=EXTRACTION_SYSTEM_PROMPT,
        messages=[{
            "role": "user",
            "content": f"""Extract resume data from: {file_path}

Extract:
- personal_info:
  - name
  - email
  - phone
  - location
  - linkedin
  - website
- summary (professional summary/objective)
- experience: [{
    company,
    title,
    start_date,
    end_date,
    location,
    responsibilities: []
  }]
- education: [{
    institution,
    degree,
    field,
    graduation_date,
    gpa (if listed)
  }]
- skills: []
- certifications: [{name, issuer, date}]
- languages: [{language, proficiency}]
- projects: [{name, description, technologies}]

Handle various resume formats (chronological, functional, combined)."""
        }],
        tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
    )

    for content in response.content:
        if hasattr(content, 'text'):
            try:
                return json.loads(content.text)
            except:
                return {"raw": content.text}

    return {}

def extract_bank_statement(file_path: str) -> Dict:
    """Extract data from a bank statement."""

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=8192,
        system=EXTRACTION_SYSTEM_PROMPT,
        messages=[{
            "role": "user",
            "content": f"""Extract bank statement data from: {file_path}

Use extract_tables for transaction data.

Extract:
- bank_name
- account_holder
- account_number (last 4 digits only for security)
- account_type
- statement_period:
  - start_date
  - end_date
- opening_balance
- closing_balance
- transactions: [{
    date,
    description,
    type (debit/credit),
    amount,
    balance
  }]
- summary:
  - total_deposits
  - total_withdrawals
  - fees

Sort transactions by date."""
        }],
        tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
    )

    for content in response.content:
        if hasattr(content, 'text'):
            try:
                return json.loads(content.text)
            except:
                return {"raw": content.text}

    return {}
```

## Step 4: Batch processing

```python
def batch_process(directory: str, document_type: str = "auto") -> List[Dict]:
    """Process all documents in a directory."""

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=8192,
        system=EXTRACTION_SYSTEM_PROMPT,
        messages=[{
            "role": "user",
            "content": f"""Process all documents in: {directory}

1. Use list_files to get all PDFs
2. For each document:
   a. Determine document type {'automatically' if document_type == 'auto' else f'(type: {document_type})'}
   b. Extract appropriate data
   c. Validate extraction
   d. Use save_extracted_data to store results

Track:
- Total documents processed
- Successful extractions
- Failed extractions with reasons

Return summary and any issues."""
        }],
        tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
    )

    for content in response.content:
        if hasattr(content, 'text'):
            try:
                return json.loads(content.text)
            except:
                return {"raw": content.text}

    return []

def classify_document(file_path: str) -> str:
    """Classify a document by type."""

    response = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=256,
        messages=[{
            "role": "user",
            "content": f"""Classify this document: {file_path}

1. Extract first page text
2. Analyze layout and content
3. Classify as one of:
   - invoice
   - contract
   - receipt
   - resume
   - bank_statement
   - form
   - report
   - letter
   - other

Output only the classification type."""
        }],
        tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
    )

    for content in response.content:
        if hasattr(content, 'text'):
            return content.text.strip().lower()

    return "other"

def process_document(file_path: str) -> Dict:
    """Auto-detect and process a document."""

    # First classify
    doc_type = classify_document(file_path)

    # Then extract based on type
    extractors = {
        "invoice": extract_invoice,
        "contract": extract_contract,
        "receipt": extract_receipt,
        "resume": extract_resume,
        "bank_statement": extract_bank_statement,
        "form": extract_form
    }

    extractor = extractors.get(doc_type, extract_form)
    result = extractor(file_path)

    return {
        "file": file_path,
        "document_type": doc_type,
        "data": result
    }
```

## Step 5: CLI tool

```python
#!/usr/bin/env python3
"""Document Processor CLI."""

import argparse
import json
import os

def main():
    parser = argparse.ArgumentParser(description="AI Document Processor")
    subparsers = parser.add_subparsers(dest="command", help="Commands")

    # Extract
    extract_parser = subparsers.add_parser("extract", help="Extract data")
    extract_parser.add_argument("file", help="Document path")
    extract_parser.add_argument("--type", "-t", help="Document type",
                               choices=["invoice", "contract", "receipt", "resume",
                                       "bank_statement", "form", "auto"],
                               default="auto")
    extract_parser.add_argument("--output", "-o", help="Output file")

    # Batch
    batch_parser = subparsers.add_parser("batch", help="Batch process")
    batch_parser.add_argument("directory", help="Directory with documents")
    batch_parser.add_argument("--type", "-t", default="auto")
    batch_parser.add_argument("--output", "-o", help="Output directory")

    # Classify
    classify_parser = subparsers.add_parser("classify", help="Classify document")
    classify_parser.add_argument("file", help="Document path")

    # OCR
    ocr_parser = subparsers.add_parser("ocr", help="OCR a document")
    ocr_parser.add_argument("file", help="Document path")
    ocr_parser.add_argument("--lang", "-l", default="eng")

    # Tables
    tables_parser = subparsers.add_parser("tables", help="Extract tables")
    tables_parser.add_argument("file", help="Document path")
    tables_parser.add_argument("--page", "-p", type=int, default=1)

    args = parser.parse_args()

    if args.command == "extract":
        if args.type == "auto":
            result = process_document(args.file)
        else:
            extractors = {
                "invoice": extract_invoice,
                "contract": extract_contract,
                "receipt": extract_receipt,
                "resume": extract_resume,
                "bank_statement": extract_bank_statement,
                "form": extract_form
            }
            result = extractors[args.type](args.file)

        output = json.dumps(result, indent=2)

        if args.output:
            with open(args.output, "w") as f:
                f.write(output)
            print(f"Saved to {args.output}")
        else:
            print(output)

    elif args.command == "batch":
        results = batch_process(args.directory, args.type)

        if args.output:
            os.makedirs(args.output, exist_ok=True)
            for result in results:
                filename = os.path.basename(result.get("file", "doc")) + ".json"
                with open(os.path.join(args.output, filename), "w") as f:
                    json.dump(result, f, indent=2)
            print(f"Saved {len(results)} files to {args.output}")
        else:
            print(json.dumps(results, indent=2))

    elif args.command == "classify":
        result = classify_document(args.file)
        print(result)

    elif args.command == "ocr":
        response = client.messages.create(
            model="claude-sonnet-4-20250514",
            max_tokens=8192,
            messages=[{
                "role": "user",
                "content": f"Use ocr_document on {args.file} with language {args.lang}"
            }],
            tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
        )
        for c in response.content:
            if hasattr(c, 'text'):
                print(c.text)

    elif args.command == "tables":
        response = client.messages.create(
            model="claude-sonnet-4-20250514",
            max_tokens=4096,
            messages=[{
                "role": "user",
                "content": f"Use extract_tables on {args.file} page {args.page}"
            }],
            tools=[{"type": "mcp", "server_url": MCP_URL, "token": MCP_TOKEN}]
        )
        for c in response.content:
            if hasattr(c, 'text'):
                print(c.text)

    else:
        parser.print_help()

if __name__ == "__main__":
    main()
```

Usage:

```bash
# Extract from invoice
./docprocess.py extract invoice.pdf --type invoice

# Auto-detect and extract
./docprocess.py extract document.pdf --output data.json

# Batch process directory
./docprocess.py batch invoices/ --type invoice --output extracted/

# Classify a document
./docprocess.py classify unknown.pdf

# OCR a scanned document
./docprocess.py ocr scanned.pdf --lang eng

# Extract tables
./docprocess.py tables report.pdf --page 3
```

## Summary

Building a document processor:

1. **Text extraction** - PDF parsing and OCR
2. **Schema-based extraction** - Structured data for each document type
3. **Validation** - Ensure data quality
4. **Batch processing** - Handle many documents
5. **Auto-classification** - Detect document types

Build tools with [Gantz](https://gantz.run), unlock data from any document.

PDFs to JSON. At scale.

## Related reading

- [AI Data Analyst](/post/data-analyst-agent/) - Data processing
- [Research Assistant](/post/research-assistant/) - Document analysis
- [Build a Translation Agent](/post/translation-agent/) - Multi-language docs

---

*How do you handle document processing? Share your approach.*
