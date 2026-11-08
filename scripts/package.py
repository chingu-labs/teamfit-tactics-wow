"""Build an addon ZIP with the directory layout expected by WoW."""

from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile


root = Path(__file__).resolve().parent.parent
output = root / "dist" / "teamfit-tactics-wow-0.1.0.zip"
output.parent.mkdir(exist_ok=True)
files = sorted((root / "TeamfitTactics").glob("*"))
with ZipFile(output, "w", compression=ZIP_DEFLATED) as archive:
    for source in files:
        if source.is_file():
            archive.write(source, source.relative_to(root))
    archive.write(root / "LICENSE", "TeamfitTactics/LICENSE")
    archive.write(root / "README.md", "TeamfitTactics/README.md")
print(output)

