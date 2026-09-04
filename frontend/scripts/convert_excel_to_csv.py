#!/usr/bin/env python3
"""简单的 Excel 转 CSV 转换脚本。
用法示例:
  python scripts/convert_excel_to_csv.py "C:/.../监控数据.xlsx"
  python scripts/convert_excel_to_csv.py input.xlsx -o output.csv
  python scripts/convert_excel_to_csv.py input.xlsx -o out_dir/
如果 Excel 有多个 sheet，会为每个 sheet 生成单独的 CSV 文件。
"""
import argparse
from pathlib import Path
import sys
import pandas as pd


def safe_name(name: str) -> str:
    return "".join(c if (c.isalnum() or c in (' ','.','_','-')) else '_' for c in name).strip()


def main():
    parser = argparse.ArgumentParser(description='Convert Excel to CSV (handles multiple sheets).')
    parser.add_argument('excel', help='Path to Excel file')
    parser.add_argument('-o', '--out', help='Output file or directory (optional)')
    args = parser.parse_args()

    excel_path = Path(args.excel)
    if not excel_path.exists():
        print(f"Error: file not found: {excel_path}")
        sys.exit(2)

    # 读取所有 sheet
    try:
        sheets = pd.read_excel(excel_path, sheet_name=None, engine='openpyxl')
    except Exception as e:
        print(f"Error reading Excel: {e}")
        sys.exit(3)

    if len(sheets) == 1:
        # 单 sheet，产出单个 CSV
        name, df = next(iter(sheets.items()))
        if args.out:
            out_path = Path(args.out)
            if out_path.is_dir():
                out_file = out_path / f"{excel_path.stem}.csv"
            else:
                out_file = out_path
        else:
            out_file = excel_path.with_suffix('.csv')

        df.to_csv(out_file, index=False)
        print(f"Wrote: {out_file}")
    else:
        # 多 sheet，输出到目录（指定文件名则视为目录）
        if args.out:
            out_dir = Path(args.out)
        else:
            out_dir = excel_path.with_name(excel_path.stem + '_csv')
        out_dir.mkdir(parents=True, exist_ok=True)

        for sheet_name, df in sheets.items():
            fn = f"{excel_path.stem}_{safe_name(sheet_name)}.csv"
            out_file = out_dir / fn
            df.to_csv(out_file, index=False)
            print(f"Wrote: {out_file}")


if __name__ == '__main__':
    main()
