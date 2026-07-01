\# Hospital Readmissions Analytics Platform



End-to-end healthcare analytics solution analyzing 30-day hospital readmissions across 101K+ inpatient encounters from 130 US hospitals, aligned with CMS Hospital Readmissions Reduction Program (HRRP) standards.



\## Status

🚧 \*\*In active development\*\* — currently building data ingestion and dbt transformation layer.



\## Business Context

The CMS Hospital Readmissions Reduction Program (HRRP) financially penalizes hospitals whose risk-adjusted 30-day readmission rates exceed national benchmarks. For diabetic populations specifically, readmissions cost the US healthcare system an estimated $25B annually. This project builds an analytics pipeline and explainable predictive model to identify drivers of readmission risk.



\## Tech Stack

| Layer | Tool |

|-------|------|

| Storage | PostgreSQL 16 |

| Transformation | dbt-postgres |

| Machine Learning | Python (scikit-learn, XGBoost) |

| Explainability | SHAP (aligned with NIST AI RMF) |

| Business Intelligence | Power BI Desktop |



\## Data Source

\[UCI ML Repository: Diabetes 130-US Hospitals for Years 1999-2008](https://archive.ics.uci.edu/dataset/296/diabetes+130-us+hospitals+for+years+1999-2008) — 101,766 inpatient encounters, 50 attributes including ICD-9 diagnosis codes, lab results, medications, and readmission outcomes.



\## Project Structure

