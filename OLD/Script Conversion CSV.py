#pip install pandas openpyxl
import pandas as pd
import os

# Nombre del archivo original
archivo_excel = 'tablas_silver_enero_febrero.xlsx'

try:
    excel = pd.ExcelFile(archivo_excel)
    
    print(f"--- Iniciando conversion de {archivo_excel} ---")

    for nombre_hoja in excel.sheet_names:

        df = pd.read_excel(archivo_excel, sheet_name=nombre_hoja, dtype=str)
   
        nombre_csv = f"{nombre_hoja.strip().replace(' ', '_')}.csv"
        
        df.to_csv(nombre_csv, index=False, encoding='utf-8-sig', sep=',')
        
        print(f" Exportado: {nombre_csv}")

    print("--- ¡Proceso terminado! Ya puedes ir a DBeaver ---")

except FileNotFoundError:
    print(f"Error: No encuentro el archivo '{archivo_excel}'")

