import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'dynamic_legal_form_page.dart';

class LegalTemplateLibraryPage extends StatefulWidget {
  final bool embedded;
  const LegalTemplateLibraryPage({super.key, this.embedded = false});

  @override
  State<LegalTemplateLibraryPage> createState() =>
      _LegalTemplateLibraryPageState();
}

class _LegalTemplateLibraryPageState extends State<LegalTemplateLibraryPage> {
  static const _navy = Color(0xFF0C1D36);
  static const _gold = Color(0xFFCFA92A);
  static const _slate = Color(0xFF64748B);

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All';

  final List<String> _categories = [
    'All',
    'Property',
    'Corporate',
    'Employment',
    'Dispute',
  ];

  // In-memory list of templates matching our system payload
  final List<Map<String, dynamic>> _templates = [
    {
      "template_id": "T-1001",
      "template_name": "Residential Tenancy Agreement",
      "category": "Property",
      "dynamic_fields": [
        {
          "field_id": "f_landlord_name",
          "label": "Landlord's Full Name (as per NRIC/Passport)",
          "type": "string",
          "required": true,
        },
        {
          "field_id": "f_landlord_ic",
          "label": "Landlord's NRIC or Passport Number",
          "type": "string",
          "required": true,
        },
        {
          "field_id": "f_tenant_name",
          "label": "Tenant's Full Name (as per NRIC/Passport)",
          "type": "string",
          "required": true,
        },
        {
          "field_id": "f_tenant_ic",
          "label": "Tenant's NRIC or Passport Number",
          "type": "string",
          "required": true,
        },
        {
          "field_id": "f_property_address",
          "label": "Full Address of the Demised Premises",
          "type": "string",
          "required": true,
        },
        {
          "field_id": "f_monthly_rental",
          "label": "Monthly Rental Amount in Ringgit Malaysia (RM)",
          "type": "number",
          "required": true,
        },
        {
          "field_id": "f_security_deposit",
          "label": "Security Deposit Amount in Ringgit Malaysia (RM)",
          "type": "number",
          "required": true,
        },
        {
          "field_id": "f_utility_deposit",
          "label": "Utility Deposit Amount in Ringgit Malaysia (RM)",
          "type": "number",
          "required": true,
        },
        {
          "field_id": "f_commencement_date",
          "label": "Tenancy Commencement Date (DD/MM/YYYY)",
          "type": "date",
          "required": true,
        },
        {
          "field_id": "f_tenancy_duration",
          "label": "Tenancy Period (in months, e.g., 12 or 24)",
          "type": "number",
          "required": true,
        },
      ],
      "document_body":
          "*** DISCLAIMER: This document is a prototype generated for the LexiGuard demonstration and does not constitute formal legal advice. *** \n\nTHIS RESIDENTIAL TENANCY AGREEMENT is made on {{f_commencement_date}}.\n\nBETWEEN:\n\n1. The party specified as the Landlord, {{f_landlord_name}} (NRIC No./Passport No.: {{f_landlord_ic}}) (hereinafter referred to as the 'Landlord') of the one part; and\n\n2. The party specified as the Tenant, {{f_tenant_name}} (NRIC No./Passport No.: {{f_tenant_ic}}) (hereinafter referred to as the 'Tenant') of the other part.\n\nWHEREAS:\n\nA. The Landlord is the registered and beneficial owner of the residential property located at {{f_property_address}} (hereinafter referred to as the 'Demised Premises').\nB. The Landlord has agreed to let and the Tenant has agreed to take the Demised Premises on tenancy subject to the terms and conditions hereinafter contained.\n\nNOW IT IS HEREBY AGREED AS FOLLOWS:\n\n1. AGREEMENT TO LET\nSubject to the provisions of this Agreement, the Landlord lets and the Tenant takes the Demised Premises for a duration of {{f_tenancy_duration}} months, commencing on {{f_commencement_date}}.\n\n2. RENTAL AND DEPOSITS\n2.1 The monthly rental for the Demised Premises shall be Ringgit Malaysia {{f_monthly_rental}} (RM{{f_monthly_rental}}) only, payable in advance on or before the 7th day of each calendar month without any deduction whatsoever.\n2.2 Upon signing this Agreement, the Tenant shall pay the Landlord a Security Deposit of Ringgit Malaysia {{f_security_deposit}} (RM{{f_security_deposit}}) only, and a Utility Deposit of Ringgit Malaysia {{f_utility_deposit}} (RM{{f_utility_deposit}}) only. Both deposits shall be held by the Landlord as security for the due performance of the Tenant's obligations and shall be refunded without interest within thirty (30) days from the expiration of this tenancy, subject to deductions for any outstanding payments, damages, or breaches.\n\n3. TENANT'S COVENANTS\nThe Tenant hereby covenants with the Landlord as follows:\n3.1 To pay the monthly rental punctually on the due dates.\n3.2 To pay all charges for water, electricity, internet, sewage, and other utilities consumed on the Demised Premises during the tenancy.\n3.3 To use the Demised Premises solely as a private residential dwelling for the Tenant and the Tenant's immediate family and not to sub-let, assign, or part with the physical possession of the Demised Premises or any part thereof to any third party without the prior written consent of the Landlord.\n3.4 To maintain the interior of the Demised Premises, including fixtures, fittings, and appliances, in good, clean, and tenantable repair and condition (fair wear and tear excepted).\n3.5 Not to make any structural alterations or additions to the Demised Premises without obtaining the prior written consent of the Landlord.\n3.6 To permit the Landlord or the Landlord's authorized agents, at all reasonable times and upon reasonable prior notice, to enter and inspect the condition of the Demised Premises.\n\n4. LANDLORD'S COVENANTS\nThe Landlord hereby covenants with the Tenant as follows:\n4.1 To pay all quit rent, assessment rates, maintenance fees, and sinking funds charged in respect of the Demised Premises.\n4.2 To maintain the main structure, roof, main sewerage, electrical wiring, and plumbing system of the Demised Premises in good repair and tenantable condition.\n4.3 That the Tenant, paying the rental and performing the covenants herein, shall peaceably hold and enjoy the Demised Premises during the tenancy without interruption by the Landlord.\n\n5. MUTUAL COVENANTS & GENERAL CLAUSES\n5.1 SEVERABILITY: If any provision of this Agreement is held to be invalid or unenforceable, such provision shall be fully severable, and the remaining provisions shall remain in full force and effect.\n5.2 GOVERNING LAW: This Agreement shall be governed by, construed, and enforced in accordance with the laws of Malaysia. The parties submit to the exclusive jurisdiction of the Courts of Malaysia in relation to any disputes arising under this Agreement.\n5.3 ENTIRE AGREEMENT: This Agreement constitutes the entire agreement between the parties and supersedes all prior agreements, oral or written, concerning the tenancy of the Demised Premises.\n\nIN WITNESS WHEREOF the parties have set their hands the day and year first above written.\n\n\nSigned by the Landlord:\n\n\n\n\n\n\n\n____________________\nName: {{f_landlord_name}}\nDate:\n\nClient Signature:\n\n\n\n\n\n\n\n\n\n\n____________________\nName: {{f_tenant_name}}\nDate:",
    },
    {
      "template_id": "T-1002",
      "template_name": "Mutual Non-Disclosure Agreement",
      "category": "Corporate",
      "dynamic_fields": [
        {
          "field_id": "f_party1_name",
          "label": "First Party's Full Name / Company Name",
          "type": "string",
          "required": true,
        },
        {
          "field_id": "f_party1_reg",
          "label": "First Party's Company Registration Number / NRIC",
          "type": "string",
          "required": true,
        },
        {
          "field_id": "f_party2_name",
          "label": "Second Party's Full Name / Company Name",
          "type": "string",
          "required": true,
        },
        {
          "field_id": "f_party2_reg",
          "label": "Second Party's Company Registration Number / NRIC",
          "type": "string",
          "required": true,
        },
        {
          "field_id": "f_effective_date",
          "label": "Effective Date of the Agreement",
          "type": "date",
          "required": true,
        },
        {
          "field_id": "f_duration_years",
          "label": "Duration of Confidentiality Obligations (in years)",
          "type": "number",
          "required": true,
        },
      ],
      "document_body":
          "*** DISCLAIMER: This document is a prototype generated for the LexiGuard demonstration and does not constitute formal legal advice. *** \n\nMUTUAL NON-DISCLOSURE AGREEMENT\n\nTHIS AGREEMENT is entered into on this {{f_effective_date}} (\"Effective Date\").\n\nBETWEEN:\n\n1. {{f_party1_name}} (Company Registration No./NRIC No. {{f_party1_reg}}) (hereinafter referred to as the \"First Party\") of the one part; and\n\n2. {{f_party2_name}} (Company Registration No./NRIC No. {{f_party2_reg}}) (hereinafter referred to as the \"Second Party\") of the other part.\n\n(Collectively referred to as the \"Parties\" and individually as a \"Party\").\n\nWHEREAS:\n\nA. The Parties wish to discuss and evaluate a potential business opportunity or transaction (the \"Purpose\").\nB. In the course of such discussions, either Party (as \"Disclosing Party\") may disclose to the other Party (as \"Receiving Party\") certain confidential, proprietary, or sensitive technical, operational, financial, or commercial information.\n\nNOW IT IS AGREED AS FOLLOWS:\n\n1. DEFINITION OF CONFIDENTIAL INFORMATION\nFor the purposes of this Agreement, \"Confidential Information\" shall mean all information, in whatever form, disclosed by the Disclosing Party to the Receiving Party that is marked confidential or which by its nature should reasonably be understood to be confidential.\n\n2. OBLIGATIONS OF RECEIVING PARTY\nThe Receiving Party shall:\n2.1 Keep all Confidential Information strictly confidential and secure using no less than reasonable care;\n2.2 Use the Confidential Information solely for the Purpose and for no other reason;\n2.3 Disclose the Confidential Information only to its employees, directors, or professional advisers who have a strict need to know and are bound by similar confidentiality terms.\n\n3. EXCLUSIONS FROM CONFIDENTIAL INFORMATION\nConfidential Information does not include information that:\n3.1 Is or becomes publicly known through no breach of this Agreement by the Receiving Party;\n3.2 Was already in the Receiving Party's possession prior to disclosure;\n3.3 Is independently developed by the Receiving Party without reference to or reliance upon the Disclosing Party's Confidential Information.\n\n4. TERM AND TERMINATION\nThis Agreement shall remain in force for a period of {{f_duration_years}} years from the Effective Date. The obligations under Clause 2 shall survive any termination of discussions for the same period.\n\n5. GOVERNING LAW AND JURISDICTION\nThis Agreement shall be governed by, and construed in accordance with, the laws of Malaysia. The Parties submit to the exclusive jurisdiction of the Courts of Malaysia to resolve any dispute arising hereunder.\n\nIN WITNESS WHEREOF the Parties have executed this Mutual Non-Disclosure Agreement on the date first above written.\n\nSigned by the First Party:\n\n\n\n\n\n____________________\nName: {{f_party1_name}}\nDate:\n\nClient Signature:\n\n\n\n\n\n\n\n____________________\nName: {{f_party2_name}}\nDate:",
    },
    {
      "template_id": "T-1003",
      "template_name": "Letter of Demand (Outstanding Debt)",
      "category": "Dispute",
      "dynamic_fields": [
        {
          "field_id": "f_creditor_name",
          "label": "Creditor's Full Name / Company Name",
          "type": "string",
          "required": true,
        },
        {
          "field_id": "f_debtor_name",
          "label": "Debtor's Full Name / Company Name",
          "type": "string",
          "required": true,
        },
        {
          "field_id": "f_debtor_address",
          "label": "Debtor's Full Address",
          "type": "string",
          "required": true,
        },
        {
          "field_id": "f_debt_amount",
          "label": "Total Outstanding Amount (RM)",
          "type": "number",
          "required": true,
        },
        {
          "field_id": "f_due_date",
          "label": "Original Date the Debt was Due",
          "type": "date",
          "required": true,
        },
        {
          "field_id": "f_grace_period_days",
          "label": "Grace Period for Payment (in days)",
          "type": "number",
          "required": true,
        },
      ],
      "document_body":
          "*** DISCLAIMER: This document is a prototype generated for the LexiGuard demonstration and does not constitute formal legal advice. *** \n\nFORMAL LETTER OF DEMAND\n\nDate: {{f_due_date}}\n\nTo:\n{{f_debtor_name}}\n{{f_debtor_address}}\n\nDear Sir/Madam,\n\nRE: DEMAND FOR PAYMENT OF OUTSTANDING DEBT AMOUNTING TO RM{{f_debt_amount}}\n\nWe refer to the above-mentioned matter.\n\nWe are instructed by our client, {{f_creditor_name}}, to demand the immediate settlement of the sum of RM{{f_debt_amount}} being the outstanding amount due and payable by you to our client. This debt was originally due for payment on {{f_due_date}}.\n\nDespite several reminders, you have failed, neglected, and/or refused to settle the said outstanding sum. Please take notice that your failure to settle this outstanding debt constitutes a serious breach of your legal obligations.\n\nWE HEREBY DEMAND that you make payment of the full sum of RM{{f_debt_amount}} to our client within {{f_grace_period_days}} days from the date of this letter, failing which we have strict instructions from our client to initiate legal proceedings against you without further reference.\n\nShould legal action be initiated, you will be liable for the costs of the action, court fees, and interest at the rate of 5% per annum from the due date until the date of full settlement.\n\nKindly guide yourselves accordingly.\n\nYours faithfully,\n\n\n\n\n\n____________________\nFor and on behalf of {{f_creditor_name}}\nDate:\n\nClient Signature:\n\n\n\n\n\n\n\n____________________\nName: {{f_debtor_name}}\nDate:",
    },
    {
      "template_id": "T-1004",
      "template_name": "Standard Employment Agreement",
      "category": "Employment",
      "dynamic_fields": [
        {
          "field_id": "f_employer_name",
          "label": "Employer's Company Name",
          "type": "string",
          "required": true,
        },
        {
          "field_id": "f_employee_name",
          "label": "Employee's Full Name (as per NRIC/Passport)",
          "type": "string",
          "required": true,
        },
        {
          "field_id": "f_employee_ic",
          "label": "Employee's NRIC / Passport Number",
          "type": "string",
          "required": true,
        },
        {
          "field_id": "f_job_title",
          "label": "Job Title",
          "type": "string",
          "required": true,
        },
        {
          "field_id": "f_salary",
          "label": "Monthly Base Salary (RM)",
          "type": "number",
          "required": true,
        },
        {
          "field_id": "f_start_date",
          "label": "Commencement Date of Employment",
          "type": "date",
          "required": true,
        },
      ],
      "document_body":
          "*** DISCLAIMER: This document is a prototype generated for the LexiGuard demonstration and does not constitute formal legal advice. *** \n\nEMPLOYMENT CONTRACT\n\nTHIS AGREEMENT is made on {{f_start_date}}.\n\nBETWEEN:\n\n1. {{f_employer_name}} (hereinafter referred to as the \"Employer\") of the one part; and\n\n2. {{f_employee_name}} (NRIC No./Passport No. {{f_employee_ic}}) (hereinafter referred to as the \"Employee\") of the other part.\n\nNOW IT IS HEREBY AGREED AS FOLLOWS:\n\n1. APPOINTMENT AND START DATE\nThe Employer hereby appoints the Employee to the position of {{f_job_title}} commencing on {{f_start_date}}. The Employee accepts this appointment subject to the terms and conditions herein.\n\n2. DURATION & PROBATION\n2.1 The Employee shall serve a probation period of three (3) months starting from the commencement date. \n2.2 Upon satisfactory performance, the Employee may be confirmed in writing.\n\n3. REMUNERATION & BENEFITS\n3.1 The Employee's monthly base salary shall be RM{{f_salary}}, payable in arrears on or before the last day of each calendar month, subject to statutory deductions (EPF, SOCSO, EIS, PCB).\n3.2 The Employee shall be entitled to annual leave, medical leave, and hospitalization benefits in accordance with the Malaysian Employment Act 1955.\n\n4. TERMINATION\nEither Party may terminate this contract during probation by giving two (2) weeks' written notice, or upon confirmation, by giving one (1) month's written notice, or payment in lieu of such notice.\n\n5. GOVERNING LAW\nThis employment contract is governed by and shall be construed in accordance with the Employment Act 1955 and the laws of Malaysia.\n\nIN WITNESS WHEREOF the parties have set their hands on the day and year first above written.\n\n\nSigned by the Employer:\n\n\n\n\n\n____________________\nName: {{f_employer_name}}\nDate:\n\nClient Signature:\n\n\n\n\n\n\n\n____________________\nName: {{f_employee_name}}\nDate:",
    },
    {
      "template_id": "T-1005",
      "template_name": "Commercial Service & Consulting Agreement",
      "category": "Corporate",
      "dynamic_fields": [
        {
          "field_id": "f_client_name",
          "label": "Client's Company Name",
          "type": "string",
          "required": true,
        },
        {
          "field_id": "f_consultant_name",
          "label": "Consultant's Name / Company Name",
          "type": "string",
          "required": true,
        },
        {
          "field_id": "f_services_desc",
          "label": "Detailed Description of Services",
          "type": "string",
          "required": true,
        },
        {
          "field_id": "f_consulting_fee",
          "label": "Consulting Fee Amount (RM)",
          "type": "number",
          "required": true,
        },
        {
          "field_id": "f_payment_terms",
          "label": "Payment Term Conditions (e.g. within 14 days of invoice)",
          "type": "string",
          "required": true,
        },
        {
          "field_id": "f_start_date",
          "label": "Agreement Start Date",
          "type": "date",
          "required": true,
        },
      ],
      "document_body":
          "*** DISCLAIMER: This document is a prototype generated for the LexiGuard demonstration and does not constitute formal legal advice. *** \n\nCOMMERCIAL SERVICES AGREEMENT\n\nTHIS AGREEMENT is made on {{f_start_date}}.\n\nBETWEEN:\n\n1. {{f_client_name}} (hereinafter referred to as the \"Client\") of the one part; and\n\n2. {{f_consultant_name}} (hereinafter referred to as the \"Consultant\") of the other part.\n\n(Collectively referred to as the \"Parties\").\n\nNOW IT IS AGREED AS FOLLOWS:\n\n1. SERVICES\nThe Consultant shall provide the following professional consulting services to the Client: {{f_services_desc}} (hereinafter referred to as the \"Services\").\n\n2. FEES AND PAYMENT\n2.1 In consideration of the Services, the Client shall pay the Consultant a fee of RM{{f_consulting_fee}}.\n2.2 Payment shall be paid under the following terms: {{f_payment_terms}}.\n\n3. INDEPENDENT CONTRACTOR STATUS\nThe Relationship between the Client and the Consultant is that of an independent contractor. Nothing in this Agreement shall be construed to create a partnership, joint venture, agency, or employment relationship.\n\n4. CONFIDENTIALITY\nBoth Parties agree to keep all commercial and business information obtained in relation to this Agreement confidential during and after the duration of this Services Agreement.\n\n5. GOVERNING LAW\nThis Agreement shall be governed by, and construed in accordance with, the laws of Malaysia. Any disputes arising out of this Agreement shall be referred to arbitration under the Asian International Arbitration Centre (AIAC) in Kuala Lumpur.\n\nIN WITNESS WHEREOF the Parties have set their hands the day and year first above written.\n\n\nSigned by the Consultant:\n\n\n\n\n\n____________________\nName: {{f_consultant_name}}\nDate:\n\nClient Signature:\n\n\n\n\n\n\n\n____________________\nName: {{f_client_name}}\nDate:",
    },
    {
      "template_id": "T-1006",
      "template_name": "General Partnership Agreement",
      "category": "Corporate",
      "dynamic_fields": [
        {
          "field_id": "f_partner1_name",
          "label": "First Partner's Full Name (as per NRIC)",
          "type": "string",
          "required": true,
        },
        {
          "field_id": "f_partner2_name",
          "label": "Second Partner's Full Name (as per NRIC)",
          "type": "string",
          "required": true,
        },
        {
          "field_id": "f_business_name",
          "label": "Proposed Partnership Business Name",
          "type": "string",
          "required": true,
        },
        {
          "field_id": "f_capital_contribution",
          "label": "Initial Capital Contribution per Partner (RM)",
          "type": "number",
          "required": true,
        },
        {
          "field_id": "f_profit_share_percent",
          "label": "Profit and Loss Share Percentage",
          "type": "number",
          "required": true,
        },
        {
          "field_id": "f_start_date",
          "label": "Partnership Commencement Date",
          "type": "date",
          "required": true,
        },
      ],
      "document_body":
          "*** DISCLAIMER: This document is a prototype generated for the LexiGuard demonstration and does not constitute formal legal advice. *** \n\nPARTNERSHIP AGREEMENT\n\nTHIS AGREEMENT is made on {{f_start_date}}.\n\nBETWEEN:\n\n1. {{f_partner1_name}} (hereinafter referred to as the \"First Partner\") of the first part; and\n\n2. {{f_partner2_name}} (hereinafter referred to as the \"Second Partner\") of the second part.\n\n(Collectively referred to as the \"Partners\").\n\nNOW IT IS AGREED AS FOLLOWS:\n\n1. BUSINESS AND NAME\nThe Partners agree to form a general partnership under the laws of Malaysia to conduct business under the name: {{f_business_name}}.\n\n2. CAPITAL CONTRIBUTION\nEach Partner shall contribute an initial capital sum of RM{{f_capital_contribution}} to the partnership business bank account within thirty (30) days from the commencement of this Agreement.\n\n3. SHARING OF PROFITS AND LOSSES\nAll profits, losses, and distributions of the partnership business shall be shared between the Partners on the following basis: {{f_profit_share_percent}}% to the First Partner and {{f_profit_share_percent}}% to the Second Partner.\n\n4. MANAGEMENT & VOTING\nBoth Partners shall have equal rights in the management and conduct of the Partnership business, and decisions shall require mutual written consent.\n\n5. GOVERNING LAW\nThis Partnership Agreement shall be governed by, and construed in accordance with, the Partnership Act 1961 and the laws of Malaysia. The Partners submit to the exclusive jurisdiction of the Courts of Malaysia.\n\nIN WITNESS WHEREOF the Partners have executed this Partnership Agreement on the day and year first above written.\n\n\nSigned by the First Partner:\n\n\n\n\n\n____________________\nName: {{f_partner1_name}}\nDate:\n\nClient Signature:\n\n\n\n\n\n\n\n____________________\nName: {{f_partner2_name}}\nDate:",
    },
  ];

  @override
  Widget build(BuildContext context) {
    // 1. Filtering logic combining category selection and text search
    final filteredTemplates = _templates.where((template) {
      final name = (template['template_name'] as String? ?? '').toLowerCase();
      final category = (template['category'] as String? ?? '').toLowerCase();
      final matchesSearch = name.contains(_searchQuery.toLowerCase());

      final matchesCategory =
          _selectedCategory == 'All' ||
          category == _selectedCategory.toLowerCase();

      return matchesSearch && matchesCategory;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: widget.embedded
          ? null
          : AppBar(
              title: Text(
                'Document Templates',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  color: _navy,
                  fontSize: 18,
                ),
              ),
              backgroundColor: Colors.white,
              elevation: 0,
              iconTheme: const IconThemeData(color: _navy),
            ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Bar & Headers
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select a Legal Template',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _navy,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Choose from standard Malaysian agreements to dynamically compile and sign.',
                  style: GoogleFonts.inter(fontSize: 13, color: _slate),
                ),
                const SizedBox(height: 16),

                // Sleek Search Bar
                TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search templates...',
                    hintStyle: GoogleFonts.inter(
                      color: Colors.grey[400],
                      fontSize: 14,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: _slate,
                      size: 20,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.clear_rounded,
                              color: _slate,
                              size: 18,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Horizontal Category Chip Row
          Container(
            color: Colors.white,
            height: 52,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final categoryName = _categories[index];
                final isSelected = _selectedCategory == categoryName;
                return Padding(
                  padding: const EdgeInsets.only(right: 8, bottom: 8),
                  child: ChoiceChip(
                    label: Text(
                      categoryName,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.w500,
                        color: isSelected ? Colors.white : _navy,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: _navy,
                    backgroundColor: const Color(0xFFF1F5F9),
                    elevation: 0,
                    pressElevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedCategory = categoryName;
                        });
                      }
                    },
                  ),
                );
              },
            ),
          ),

          // Template Grid/List View
          Expanded(
            child: filteredTemplates.isEmpty
                ? _buildEmptyState()
                : GridView.builder(
                    padding: const EdgeInsets.all(20),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.82,
                        ),
                    itemCount: filteredTemplates.length,
                    itemBuilder: (context, index) {
                      final template = filteredTemplates[index];
                      final name =
                          template['template_name'] as String? ??
                          'Contract Template';
                      final cat = template['category'] as String? ?? 'General';
                      final fieldsCount =
                          (template['dynamic_fields'] as List? ?? []).length;

                      return GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  DynamicLegalFormPage(templateData: template),
                            ),
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Category Badge
                              Container(
                                decoration: BoxDecoration(
                                  color: _getCategoryColor(
                                    cat,
                                  ).withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                child: Text(
                                  cat.toUpperCase(),
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: _getCategoryColor(cat),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              const Spacer(),

                              // Category Custom Icon
                              Icon(
                                _getCategoryIcon(cat),
                                color: _navy.withValues(alpha: 0.7),
                                size: 28,
                              ),
                              const SizedBox(height: 12),

                              // Template Name
                              Text(
                                name,
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.bold,
                                  color: _navy,
                                  fontSize: 14,
                                  height: 1.3,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),

                              // Required Fields Count
                              Text(
                                '$fieldsCount dynamic inputs',
                                style: GoogleFonts.inter(
                                  color: _slate,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 10),

                              // Prototype Status Tag
                              Row(
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: _gold,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    'Prototype Baseline',
                                    style: GoogleFonts.inter(
                                      color: _slate,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search_off_rounded,
                color: _slate,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No templates found',
              style: GoogleFonts.inter(
                color: _navy,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'We couldn\'t find any templates matching your search criteria. Try selecting another category or refining your query.',
              style: GoogleFonts.inter(
                color: _slate,
                fontSize: 12.5,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'property':
        return const Color(0xFFD97706); // Amber
      case 'corporate':
        return const Color(0xFF2563EB); // Blue
      case 'employment':
        return const Color(0xFF059669); // Emerald
      case 'dispute':
        return const Color(0xFFDC2626); // Red
      default:
        return const Color(0xFF4B5563); // Gray
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'property':
        return Icons.home_work_outlined;
      case 'corporate':
        return Icons.business_center_outlined;
      case 'employment':
        return Icons.badge_outlined;
      case 'dispute':
        return Icons.gavel_outlined;
      default:
        return Icons.description_outlined;
    }
  }
}
