import os
import re
import docx
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT
from docx.oxml import OxmlElement
from docx.oxml.ns import qn

def set_cell_background(cell, fill_hex):
    tcPr = cell._tc.get_or_add_tcPr()
    shd = OxmlElement('w:shd')
    shd.set(qn('w:val'), 'clear')
    shd.set(qn('w:color'), 'auto')
    shd.set(qn('w:fill'), fill_hex)
    tcPr.append(shd)

def create_mobile_dev_doc(output_path):
    doc = docx.Document()
    
    # Page Margins
    for section in doc.sections:
        section.top_margin = Inches(0.8)
        section.bottom_margin = Inches(0.8)
        section.left_margin = Inches(0.8)
        section.right_margin = Inches(0.8)

    # Title
    title = doc.add_paragraph()
    r_title = title.add_run("ZeParty Mobile Developer Action Guide\n10 October 2026 Specification")
    r_title.bold = True
    r_title.font.size = Pt(22)
    r_title.font.color.rgb = RGBColor(26, 35, 126) # Deep Navy
    title.alignment = WD_ALIGN_PARAGRAPH.CENTER

    sub = doc.add_paragraph()
    r_sub = sub.add_run("Client & Platform Engineering Directives | Host Center Correction, Country-Filtered Withdrawals, Wealth Level XP Fix, Direct Live Video Host Registration & Agency Wallet")
    r_sub.font.size = Pt(10)
    r_sub.italic = True
    r_sub.font.color.rgb = RGBColor(90, 100, 120)
    sub.alignment = WD_ALIGN_PARAGRAPH.CENTER

    doc.add_paragraph().paragraph_format.space_after = Pt(12)

    # Executive Notice Box
    table = doc.add_table(rows=1, cols=1)
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    cell = table.cell(0, 0)
    set_cell_background(cell, "E8EAF6") # Soft Indigo Tint
    p_box = cell.paragraphs[0]
    p_box.paragraph_format.left_indent = Inches(0.1)
    p_box.paragraph_format.right_indent = Inches(0.1)
    r_box_title = p_box.add_run("IMPORTANT NOTICE FOR MOBILE (FLUTTER) DEVELOPER:\n")
    r_box_title.bold = True
    r_box_title.font.size = Pt(11)
    r_box_title.font.color.rgb = RGBColor(13, 71, 161)
    r_box_body = p_box.add_run(
        "All required backend endpoints, database schemas, and admin portal controls have been fully implemented, tested, and deployed. "
        "The mobile developer must implement the following UI, state management, and API integration tasks inside the Flutter client as specified below. "
        "Strictly adhere to the Zero Initial State Policy for new hosts, Country-Filtered Recipient rules, and true Wealth XP progression."
    )
    r_box_body.font.size = Pt(9.5)
    r_box_body.font.color.rgb = RGBColor(33, 33, 33)

    doc.add_paragraph().paragraph_format.space_after = Pt(14)

    # -------------------------------------------------------------
    # SECTION 1: Audio Host Center Data Correction & Zero Initial State
    # -------------------------------------------------------------
    h1 = doc.add_heading("1. Audio Host Center: Zero Initial State & Data Correction", level=1)
    h1.runs[0].font.color.rgb = RGBColor(26, 35, 126)

    doc.add_paragraph(
        "Problem: When a new audio host opens the Audio Host Center, the screen previously displayed hardcoded sample values: "
        "15,000 achieved coins, $2.00 salary, $1.60 host share, $0.40 agency share, 10/10 attendance, and 120/120 minutes. "
        "These placeholder values must NEVER be displayed for a genuinely new host with no recorded streaming activity."
    )

    doc.add_heading("1.1 Required Initial State for New Hosts (Flutter UI & Providers)", level=2)
    
    # Table of Initial Values
    t_init = doc.add_table(rows=1, cols=2)
    t_init.alignment = WD_TABLE_ALIGNMENT.CENTER
    hdr = t_init.rows[0].cells
    hdr[0].text = "Host Center Screen Field"
    hdr[1].text = "Required Display for New Host (0 Activity)"
    set_cell_background(hdr[0], "1A237E")
    set_cell_background(hdr[1], "1A237E")
    for cell in hdr:
        for p in cell.paragraphs:
            for r in p.runs:
                r.bold = True
                r.font.color.rgb = RGBColor(255, 255, 255)
                r.font.size = Pt(9.5)

    fields = [
        ("Achieved coins or diamonds", "0"),
        ("Target progress bar", "0% (empty progress fill)"),
        ("Basic Total Salary", "$0.00"),
        ("Host Basic Salary (You)", "$0.00"),
        ("Agency Share earned from this host", "$0.00"),
        ("Special ID Bonus earned", "$0.00"),
        ("Completed valid days", "0 / 10 days (0 / required days)"),
        ("Today tracked time", "0 / 120 mins (0 / required minutes)"),
        ("Today streaming status", "Not started"),
        ("Available Host Salary", "$0.00 USD"),
        ("Pending salary & pending withdrawal", "$0.00"),
        ("Total earned and total withdrawn", "$0.00"),
        ("Salary and withdrawal history", "Empty state: 'No records yet'"),
    ]

    for f_name, f_val in fields:
        row = t_init.add_row().cells
        row[0].text = f_name
        row[1].text = f_val
        set_cell_background(row[0], "F5F5F5")
        set_cell_background(row[1], "FFFFFF")
        for cell in row:
            for p in cell.paragraphs:
                for r in p.runs:
                    r.font.size = Pt(9)

    doc.add_paragraph().paragraph_format.space_after = Pt(8)

    doc.add_heading("1.2 Policy Rules vs. Earned Data (Crucial Distinction)", level=2)
    doc.add_paragraph(
        "• Policy targets are RULES, not earned progress: The configured target of 10 valid days and 120 minutes per day must remain visible as requirements (i.e. display '0 / 10 days' and '0 / 120 minutes'). Do not hide the targets.\n"
        "• Policy Payout Table: If the screen displays the Host Policy Table (Lv 1–Lv 25), clearly label it as 'Policy Rules / Potential Payouts' so it is not confused with current earned balances."
    )

    doc.add_heading("1.3 Host Identity Binding & Account Switch Reset", level=2)
    doc.add_paragraph(
        "• Authenticated Identity: Load the authenticated host's actual display name, unique public user ID, and starting level (Lv. 1). Remove hardcoded demo names like 'Javis'.\n"
        "• Agency Assignment: Bind actual agency membership. If the host has not joined an agency, display 'No agency joined'. Never fallback to 'agency_101'.\n"
        "• Account Switch & Logout: When the user logs out or switches accounts, immediately clear the previous host data from local state/providers (`AgencyProvider`, `UsdBalanceProvider`). Wait for the new host API response before displaying personal numbers.\n"
        "• API Error Handling: If the network fails, display an error message with a 'Retry' button. Never silently overwrite real balances with zero upon a network failure."
    )

    doc.add_heading("1.4 Attendance Progression & Withdrawal Button Logic", level=2)
    doc.add_paragraph(
        "• Attendance Timer: Today tracked time starts at 0 minutes. Count a valid day only when the approved 120 minutes condition is met.\n"
        "• Status at Target Completion: When tracked time reaches 120/120 minutes and attendance criteria are satisfied, display 'Completed'. Do not display 'In progress' at 120/120.\n"
        "• Withdraw Button: Disable the 'Withdraw' button when available host balance is $0.00. Enable only when eligible funds > $0.00."
    )

    # -------------------------------------------------------------
    # SECTION 2: Withdrawal Recipients Filtered by User ID Country
    # -------------------------------------------------------------
    doc.add_heading("2. Withdrawal Recipients by User ID Country", level=1)
    doc.add_paragraph(
        "Rule: When requesting a withdrawal, the host must ONLY see active, authorized Coin Sellers and Merchants registered for the exact country saved on their backend User ID (`user.countryCode`)."
    )

    doc.add_heading("2.1 Country Authority Rules", level=2)
    doc.add_paragraph(
        "• Strict Backend Source: Use only the country saved against the authenticated user ID on the backend.\n"
        "• Disallowed Sources: Do NOT determine recipients using device GPS, IP location, VPN, SIM card country, phone prefix, or device language.\n"
        "• Cross-Country Filtering: Pakistan User ID (PK) -> Pakistan Coin Sellers & Merchants ONLY. India User ID (IN) -> India Coin Sellers & Merchants ONLY."
    )

    doc.add_heading("2.2 Mobile Recipient Screen Updates (`WithdrawalScreen.dart`)", level=2)
    doc.add_paragraph(
        "• API Endpoint: Call `GET /v1/finance/withdrawal-recipients?type=COIN_SELLER` or `GET /v1/finance/withdrawal-recipients?type=MERCHANT`.\n"
        "• Remove Hardcoded Selection: Remove 'Global Reseller Alpha'. Render real recipients returned by the backend with their real name, unique public ID, country flag, and role.\n"
        "• Tab Switching: Switching between 'Coin Sellers' and 'Merchants' tabs must clear previous recipient selection and fetch the matching list.\n"
        "• Empty List Handling: If the country has no eligible recipient, display: 'No authorized coin seller available in your country' or 'No authorized merchant available in your country'. Keep confirm button disabled.\n"
        "• Amount Input Field: Must start completely EMPTY with placeholder 'Enter amount'. Remove the fixed $450.00 sample amount. Validate entered amount against available host balance."
    )

    # -------------------------------------------------------------
    # SECTION 3: Live Video Host Direct Registration
    # -------------------------------------------------------------
    doc.add_heading("3. Live Video Host Direct Platform Registration", level=1)
    doc.add_paragraph(
        "Rule: Live Video Hosts register directly inside the mobile app without requiring an agency. The agency system is strictly for audio hosts."
    )
    doc.add_paragraph(
        "• Single Registration Type: Keep only 'Live Video Host' as the direct registration option. Remove 'Live Video & Audio Party Host' and 'Social Audio & Party Host' from this live registration flow.\n"
        "• No Agency Required: Remove agency picker, agency invitation code input, and agency owner approval steps from the live host application form.\n"
        "• Admin Routing: Live host applications are sent to platform admin review. Once approved, the live host is managed via the Platform Live Host Center.\n"
        "• Personal Wallet Settlement: Live video host earnings route 100% to the host's personal Live Host Salary Wallet. They do not route through an Agency Wallet or generate audio agency commission."
    )

    # -------------------------------------------------------------
    # SECTION 4: Agency Wallet Commission & Withdrawal Flow
    # -------------------------------------------------------------
    doc.add_heading("4. Agency Wallet: Owner Commission & Withdrawal", level=1)
    doc.add_paragraph(
        "Rule: In Agency Center -> Agency Wallet, only the agency owner's earned commission is credited. Host personal salaries remain in each host's personal Host Wallet."
    )
    doc.add_paragraph(
        "• Text Correction: Replace the old notice with: 'Agency Wallet receives only the agency owner commission. Individual host salaries are credited to each host personal wallet.'\n"
        "• Ledger Title: Change header to 'Commission History'. Show entries with amount, cycle, date, and status. For new agencies, display '$0.00 Available, $0.00 Pending' and 'No commission records yet'.\n"
        "• Add Withdraw Button: Place a visible 'Withdraw' button below Available Commission. Open 'Withdraw Agency Commission' sheet with Coin Sellers / Merchants tabs.\n"
        "• Recipient Filtering: Filter recipients strictly by the Agency Owner's User ID Country. Disallow withdrawal if available commission is $0.00."
    )

    # -------------------------------------------------------------
    # SECTION 5: Wealth Level & XP Display Fix
    # -------------------------------------------------------------
    doc.add_heading("5. Wealth Level & XP Increment on Gift Sending", level=1)
    doc.add_paragraph(
        "Bug: Gift sending did not increase Wealth level in Level Center, displaying 'Wealth Active Level Lv. 1, Current XP 0, Target XP 1000.0M' with all perks unlocked as placeholders."
    )
    doc.add_paragraph(
        "• XP Target Display Fix: Fix the formatting unit in `LevelCenterScreen.dart`. The backend policy target is 10,000 XP per level (1 Coin = 1 XP). Do NOT display '1000.0M'. Display '10,000 XP' for Level 1 target.\n"
        "• Real XP Progression: Bind `userProfile.wealthXp` and `userProfile.wealthLevel` returned by backend in auth and user endpoints. Update progress bar accordingly: `progress = currentXp / (level * 10000)`.\n"
        "• Privilege Unlock State: Remove placeholder 'Unlocked' status for all perks at Level 1. Show perks as locked with lock icon until the user reaches the configured qualification level."
    )

    # -------------------------------------------------------------
    # SECTION 6: Agency System for Audio Hosts Only
    # -------------------------------------------------------------
    doc.add_heading("6. Audio Agency System Exclusivity", level=1)
    doc.add_paragraph(
        "• In mobile app Agency Center, ensure all agency creation, joining, member counts, and targets apply exclusively to Social Audio Hosts.\n"
        "• Remove any choices or mentions of 'Live Video Agency' inside the mobile client."
    )

    # -------------------------------------------------------------
    # SECTION 7: API Endpoints Reference for Mobile Dev
    # -------------------------------------------------------------
    doc.add_heading("7. Backend API Endpoints Reference Table", level=1)
    
    t_api = doc.add_table(rows=1, cols=3)
    t_api.alignment = WD_TABLE_ALIGNMENT.CENTER
    hdr = t_api.rows[0].cells
    hdr[0].text = "Method & Endpoint"
    hdr[1].text = "Purpose"
    hdr[2].text = "Key Parameters / Headers"
    set_cell_background(hdr[0], "1A237E")
    set_cell_background(hdr[1], "1A237E")
    set_cell_background(hdr[2], "1A237E")
    for cell in hdr:
        for p in cell.paragraphs:
            for r in p.runs:
                r.bold = True
                r.font.color.rgb = RGBColor(255, 255, 255)
                r.font.size = Pt(9)

    api_rows = [
        ("GET /v1/hosts/income-dashboard", "Audio Host Center Dashboard Data", "Bearer Token (Returns initial 0 values for new hosts)"),
        ("GET /v1/finance/withdrawal-recipients", "Country-Filtered Coin Sellers & Merchants", "?type=COIN_SELLER|MERCHANT (Filtered by User ID Country)"),
        ("POST /v1/finance/withdrawals", "Submit Host Salary Withdrawal Request", "{ recipientId, amountUSD, method } (Validates country & balance)"),
        ("GET /v1/agencies/:id/wallet", "Agency Owner Commission Wallet", "Owner Bearer Token (Returns owner commission only)"),
        ("POST /v1/agencies/:id/withdraw", "Agency Owner Commission Withdrawal", "{ recipientId, amountUSD } (Owner country filtered)"),
        ("POST /v1/hosts/apply-live", "Direct Live Video Host Registration", "FormData: ID docs, video demo (No agency required)"),
        ("GET /v1/users/level-strip", "4-Card Level Strip in Room", "Bearer Token (Returns live Wealth, Charm, SVIP, Game levels)"),
    ]

    for m_ep, m_purp, m_params in api_rows:
        row = t_api.add_row().cells
        row[0].text = m_ep
        row[1].text = m_purp
        row[2].text = m_params
        set_cell_background(row[0], "F5F5F5")
        set_cell_background(row[1], "FFFFFF")
        set_cell_background(row[2], "FFFFFF")
        for cell in row:
            for p in cell.paragraphs:
                for r in p.runs:
                    r.font.size = Pt(8.5)

    doc.add_paragraph().paragraph_format.space_after = Pt(16)

    # Footer note
    p_foot = doc.add_paragraph()
    r_foot = p_foot.add_run("ZeParty Mobile Developer Action Guide · Version 2026.10 · Approved for Immediate Client Implementation")
    r_foot.font.size = Pt(9)
    r_foot.italic = True
    r_foot.font.color.rgb = RGBColor(120, 120, 120)
    p_foot.alignment = WD_ALIGN_PARAGRAPH.CENTER

    doc.save(output_path)
    print(f"Successfully generated mobile doc: {output_path}")

def update_master_docx(md_path, docx_path):
    # Convert markdown to clean docx
    doc = docx.Document()
    for section in doc.sections:
        section.top_margin = Inches(0.8)
        section.bottom_margin = Inches(0.8)
        section.left_margin = Inches(0.8)
        section.right_margin = Inches(0.8)

    with open(md_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    title_added = False
    in_code_block = False
    code_block_text = []

    for line in lines:
        stripped = line.rstrip()
        
        # Code block handling
        if stripped.startswith("```"):
            if in_code_block:
                # Close code block
                in_code_block = False
                t = doc.add_table(rows=1, cols=1)
                t.alignment = WD_TABLE_ALIGNMENT.CENTER
                cell = t.cell(0, 0)
                set_cell_background(cell, "263238") # Dark Blue Grey
                p = cell.paragraphs[0]
                run = p.add_run("\n".join(code_block_text))
                run.font.name = "Consolas"
                run.font.size = Pt(8)
                run.font.color.rgb = RGBColor(236, 239, 241)
                code_block_text = []
                doc.add_paragraph().paragraph_format.space_after = Pt(4)
            else:
                in_code_block = True
                code_block_text = []
            continue

        if in_code_block:
            code_block_text.append(stripped)
            continue

        if not stripped:
            continue

        # Headings
        if stripped.startswith("# ") and not title_added:
            p = doc.add_paragraph()
            r = p.add_run(stripped[2:])
            r.bold = True
            r.font.size = Pt(20)
            r.font.color.rgb = RGBColor(26, 35, 126)
            p.alignment = WD_ALIGN_PARAGRAPH.CENTER
            title_added = True
        elif stripped.startswith("## "):
            h = doc.add_heading(stripped[3:], level=1)
            h.runs[0].font.color.rgb = RGBColor(26, 35, 126)
            h.runs[0].font.size = Pt(14)
        elif stripped.startswith("### "):
            h = doc.add_heading(stripped[4:], level=2)
            h.runs[0].font.color.rgb = RGBColor(40, 53, 147)
            h.runs[0].font.size = Pt(12)
        elif stripped.startswith("#### "):
            h = doc.add_heading(stripped[5:], level=3)
            h.runs[0].font.color.rgb = RGBColor(63, 81, 181)
            h.runs[0].font.size = Pt(10.5)
        elif stripped.startswith("- ") or stripped.startswith("* "):
            p = doc.add_paragraph(style='List Bullet')
            text = stripped[2:]
            # Bold highlights
            parts = re.split(r'(\*\*.*?\*\*)', text)
            for part in parts:
                if part.startswith('**') and part.endswith('**'):
                    r = p.add_run(part[2:-2])
                    r.bold = True
                else:
                    p.add_run(part)
        elif stripped.startswith("---"):
            p = doc.add_paragraph()
            p.paragraph_format.space_after = Pt(6)
        else:
            p = doc.add_paragraph()
            parts = re.split(r'(\*\*.*?\*\*)', stripped)
            for part in parts:
                if part.startswith('**') and part.endswith('**'):
                    r = p.add_run(part[2:-2])
                    r.bold = True
                else:
                    p.add_run(part)

    doc.save(docx_path)
    print(f"Successfully generated master doc: {docx_path}")

if __name__ == '__main__':
    base_dir = r"d:\Ze-Party"
    mobile_doc_path = os.path.join(base_dir, "ZeParty_Mobile_Developer_Action_Guide_10Oct2026.docx")
    master_md_path = os.path.join(base_dir, "ZeParty_Complete_System_Master_Guide_and_Report.md")
    master_doc_path = os.path.join(base_dir, "ZeParty_Complete_System_Master_Guide_and_Report.docx")

    create_mobile_dev_doc(mobile_doc_path)
    update_master_docx(master_md_path, master_doc_path)
