# ============================================================
# ENDPOINT EXPORT EXCEL / CSV
#
# Ce router génère les fichiers de présence téléchargeables :
# - Excel (.xlsx) avec mise en forme et modèle ENIADE
# - CSV (.csv) format brut compatible avec tous les outils
# ============================================================

from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import StreamingResponse
from sqlalchemy.orm import Session
from sqlalchemy import and_
from uuid import UUID
from datetime import datetime
import io
import csv
import openpyxl
from openpyxl.styles import (
    Font, Fill, PatternFill, Alignment,
    Border, Side
)
from openpyxl.utils import get_column_letter

from app.database import get_db
from app.models.user import User, RoleEnum
from app.models.module import Module
from app.models.session import Session as SessionModel, StatutSession
from app.models.attendance import Attendance, StatutPresence
from app.core.dependencies import require_professeur, require_admin

router = APIRouter(prefix="/export", tags=["Export"])


def get_session_data(session_id: UUID, db: Session):
    """
    Récupère toutes les données d'une session :
    - Infos de la session
    - Infos du module
    - Infos du professeur
    - Liste des présences avec infos étudiants
    """

    # Récupère la session
    session = db.query(SessionModel).filter(
        SessionModel.id == session_id
    ).first()

    if not session:
        raise HTTPException(
            status_code=404,
            detail="Session introuvable"
        )

    # Récupère le module
    module = db.query(Module).filter(
        Module.id == session.module_id
    ).first()

    # Récupère le professeur
    prof = db.query(User).filter(
        User.id == session.professeur_id
    ).first()

    # Récupère toutes les présences avec les infos étudiants
    attendances = db.query(Attendance, User).join(
        User, Attendance.etudiant_id == User.id
    ).filter(
        Attendance.session_id == session_id
    ).order_by(User.nom, User.prenom).all()

    # Calcule les statistiques
    total = len(attendances)
    presents = sum(
        1 for a, u in attendances
        if a.statut == StatutPresence.present
    )
    absents = total - presents
    taux = round((presents / total * 100), 1) if total > 0 else 0

    return {
        "session": session,
        "module": module,
        "prof": prof,
        "attendances": attendances,
        "stats": {
            "total": total,
            "presents": presents,
            "absents": absents,
            "taux": taux
        }
    }


# ============================================================
# EXPORT EXCEL
# ============================================================

@router.get("/excel/{session_id}")
def export_excel(
    session_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_professeur)
):
    """
    Génère un fichier Excel (.xlsx) avec mise en forme ENIADE.
    
    Structure du fichier :
    - En-tête avec logo ENIADE et infos session
    - Tableau des présences coloré (vert=présent, rouge=absent)
    - Ligne de statistiques en bas
    """

    # Récupère les données
    data = get_session_data(session_id, db)
    session = data["session"]
    module = data["module"]
    prof = data["prof"]
    attendances = data["attendances"]
    stats = data["stats"]

    # ── Crée le fichier Excel ─────────────────────────────────
    wb = openpyxl.Workbook()
    ws = wb.active
    ws.title = "Présences"

    # ── Couleurs ENIADE ───────────────────────────────────────
    # Bleu ENIADE pour l'en-tête
    COLOR_BLUE = "1F5C99"
    COLOR_LIGHT_BLUE = "D6E4F0"
    COLOR_GREEN = "1D9E75"
    COLOR_LIGHT_GREEN = "E1F5EE"
    COLOR_RED = "A32D2D"
    COLOR_LIGHT_RED = "FCEBEB"
    COLOR_GRAY = "F2F2F2"
    COLOR_WHITE = "FFFFFF"

    # ── Styles ────────────────────────────────────────────────
    # Style titre principal
    title_font = Font(
        name="Arial", size=16,
        bold=True, color=COLOR_WHITE
    )
    title_fill = PatternFill(
        start_color=COLOR_BLUE,
        end_color=COLOR_BLUE,
        fill_type="solid"
    )
    title_align = Alignment(
        horizontal="center",
        vertical="center"
    )

    # Style en-tête colonnes
    header_font = Font(
        name="Arial", size=11,
        bold=True, color=COLOR_WHITE
    )
    header_fill = PatternFill(
        start_color=COLOR_BLUE,
        end_color=COLOR_BLUE,
        fill_type="solid"
    )

    # Style info (sous l'en-tête)
    info_font = Font(name="Arial", size=10, bold=True, color=COLOR_BLUE)
    info_fill = PatternFill(
        start_color=COLOR_LIGHT_BLUE,
        end_color=COLOR_LIGHT_BLUE,
        fill_type="solid"
    )

    # Bordure fine
    thin_border = Border(
        left=Side(style="thin", color="CCCCCC"),
        right=Side(style="thin", color="CCCCCC"),
        top=Side(style="thin", color="CCCCCC"),
        bottom=Side(style="thin", color="CCCCCC")
    )

    # ── LIGNE 1 : Titre principal ─────────────────────────────
    ws.merge_cells("A1:F1")
    ws["A1"] = "ENIADE — Liste de présence"
    ws["A1"].font = title_font
    ws["A1"].fill = title_fill
    ws["A1"].alignment = title_align
    ws.row_dimensions[1].height = 35

    # ── LIGNES 2-6 : Informations de la session ───────────────
    infos = [
        ("Module :", f"{module.nom} ({module.code})"),
        ("Filière :", f"{module.filiere} — Semestre {module.semestre}"),
        ("Professeur :", f"{prof.prenom} {prof.nom}"),
        ("Date :", session.debut_at.strftime("%d/%m/%Y à %H:%M")),
        ("Statut :", "Fermée" if session.statut == StatutSession.fermee else "En cours"),
    ]

    for i, (label, value) in enumerate(infos, start=2):
        ws.merge_cells(f"A{i}:B{i}")
        ws.merge_cells(f"C{i}:F{i}")
        ws[f"A{i}"] = label
        ws[f"C{i}"] = value
        ws[f"A{i}"].font = info_font
        ws[f"A{i}"].fill = info_fill
        ws[f"C{i}"].font = Font(name="Arial", size=10)
        ws[f"C{i}"].fill = PatternFill(
            start_color=COLOR_WHITE,
            end_color=COLOR_WHITE,
            fill_type="solid"
        )
        ws.row_dimensions[i].height = 20

    # ── LIGNE 7 : Vide ────────────────────────────────────────
    ws.row_dimensions[7].height = 10

    # ── LIGNE 8 : En-tête tableau ─────────────────────────────
    headers = ["N°", "Nom", "Prénom", "Apogée", "Statut", "Heure pointage"]
    col_widths = [5, 20, 20, 15, 15, 20]

    for col, (header, width) in enumerate(
        zip(headers, col_widths), start=1
    ):
        cell = ws.cell(row=8, column=col, value=header)
        cell.font = header_font
        cell.fill = header_fill
        cell.alignment = Alignment(horizontal="center", vertical="center")
        cell.border = thin_border
        ws.column_dimensions[get_column_letter(col)].width = width

    ws.row_dimensions[8].height = 25

    # ── LIGNES 9+ : Données étudiants ────────────────────────
    for idx, (attendance, etudiant) in enumerate(attendances, start=1):
        row = idx + 8

        # Détermine la couleur selon le statut
        if attendance.statut == StatutPresence.present:
            status_text = "PRÉSENT"
            row_fill = PatternFill(
                start_color=COLOR_LIGHT_GREEN,
                end_color=COLOR_LIGHT_GREEN,
                fill_type="solid"
            )
            status_font = Font(
                name="Arial", size=10,
                bold=True, color=COLOR_GREEN
            )
        else:
            status_text = "ABSENT"
            row_fill = PatternFill(
                start_color=COLOR_LIGHT_RED,
                end_color=COLOR_LIGHT_RED,
                fill_type="solid"
            )
            status_font = Font(
                name="Arial", size=10,
                bold=True, color=COLOR_RED
            )

        # Heure de pointage
        pointed_at = (
            attendance.pointed_at.strftime("%H:%M:%S")
            if attendance.pointed_at else "—"
        )

        # Données de la ligne
        row_data = [
            idx,
            etudiant.nom,
            etudiant.prenom,
            etudiant.apogee or "—",
            status_text,
            pointed_at
        ]

        for col, value in enumerate(row_data, start=1):
            cell = ws.cell(row=row, column=col, value=value)
            cell.border = thin_border
            cell.alignment = Alignment(
                horizontal="center" if col in [1, 4, 5, 6] else "left",
                vertical="center"
            )
            cell.font = Font(name="Arial", size=10)
            cell.fill = row_fill

            # Style spécial pour la colonne statut
            if col == 5:
                cell.font = status_font

        ws.row_dimensions[row].height = 20

    # ── Ligne statistiques ────────────────────────────────────
    stats_row = len(attendances) + 9
    ws.row_dimensions[stats_row].height = 10

    stats_row += 1
    ws.merge_cells(f"A{stats_row}:F{stats_row}")
    stats_text = (
        f"Total : {stats['total']} étudiants  |  "
        f"Présents : {stats['presents']}  |  "
        f"Absents : {stats['absents']}  |  "
        f"Taux de présence : {stats['taux']}%"
    )
    ws[f"A{stats_row}"] = stats_text
    ws[f"A{stats_row}"].font = Font(
        name="Arial", size=11,
        bold=True, color=COLOR_BLUE
    )
    ws[f"A{stats_row}"].fill = PatternFill(
        start_color=COLOR_LIGHT_BLUE,
        end_color=COLOR_LIGHT_BLUE,
        fill_type="solid"
    )
    ws[f"A{stats_row}"].alignment = Alignment(horizontal="center")
    ws.row_dimensions[stats_row].height = 25

    # ── Sauvegarde dans un buffer mémoire ─────────────────────
    # On ne sauvegarde pas sur disque — on envoie directement
    buffer = io.BytesIO()
    wb.save(buffer)
    buffer.seek(0)

    # ── Nom du fichier ────────────────────────────────────────
    filename = (
        f"presence_{module.code}_"
        f"{session.debut_at.strftime('%Y%m%d_%H%M')}.xlsx"
    )

    # ── Retourne le fichier en réponse HTTP ───────────────────
    return StreamingResponse(
        buffer,
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={
            "Content-Disposition": f"attachment; filename={filename}"
        }
    )


# ============================================================
# EXPORT CSV
# ============================================================

@router.get("/csv/{session_id}")
def export_csv(
    session_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_professeur)
):
    """
    Génère un fichier CSV (.csv) format brut.
    Compatible avec Excel, Google Sheets, etc.
    """

    # Récupère les données
    data = get_session_data(session_id, db)
    module = data["module"]
    prof = data["prof"]
    attendances = data["attendances"]
    stats = data["stats"]
    session = data["session"]

    # ── Crée le CSV dans un buffer mémoire ────────────────────
    buffer = io.StringIO()

    # Utilise le point-virgule comme séparateur
    # (compatible Excel français)
    writer = csv.writer(buffer, delimiter=";")

    # ── En-tête du fichier ────────────────────────────────────
    writer.writerow(["ENIAD — Liste de presence"])
    writer.writerow([])
    writer.writerow(["Module", f"{module.nom} ({module.code})"])
    writer.writerow(["Filiere", f"{module.filiere} - S{module.semestre}"])
    writer.writerow(["Professeur", f"{prof.prenom} {prof.nom}"])
    writer.writerow([
        "Date",
        session.debut_at.strftime("%d/%m/%Y a %H:%M")
    ])
    writer.writerow([])

    # ── En-tête tableau ───────────────────────────────────────
    writer.writerow([
        "N°", "Nom", "Prenom",
        "Apogee", "Statut", "Heure pointage"
    ])

    # ── Données étudiants ─────────────────────────────────────
    for idx, (attendance, etudiant) in enumerate(attendances, start=1):
        status = (
            "PRESENT"
            if attendance.statut == StatutPresence.present
            else "ABSENT"
        )
        pointed_at = (
            attendance.pointed_at.strftime("%H:%M:%S")
            if attendance.pointed_at else ""
        )
        writer.writerow([
            idx,
            etudiant.nom,
            etudiant.prenom,
            etudiant.apogee or "",
            status,
            pointed_at
        ])

    # ── Statistiques finales ──────────────────────────────────
    writer.writerow([])
    writer.writerow([
        "Total", stats["total"],
        "Presents", stats["presents"],
        "Absents", stats["absents"],
        f"Taux {stats['taux']}%"
    ])

    # ── Retourne le fichier ───────────────────────────────────
    buffer.seek(0)
    filename = (
        f"presence_{module.code}_"
        f"{session.debut_at.strftime('%Y%m%d_%H%M')}.csv"
    )

    return StreamingResponse(
        iter([buffer.getvalue()]),
        media_type="text/csv",
        headers={
            "Content-Disposition": f"attachment; filename={filename}"
        }
    )