# Screen Plan 08: Dynamic Form Builder System

> **Backend Phase:** Phase 5 (Dynamic Form Builder)  
> **Target Audience:** System Admins, Form Designers, Citizen Service Officers

---

## 1. Form Template Builder Screen (`/admin/form-builder`)

### Purpose
Visual drag-and-drop schema designer for building dynamic form templates without writing front-end code.

### UI Layout & Components
- **Header:** Form Title, Code (`permit_application_v1`), Module (`building_permit`), Version Number, Active Toggle.
- **Left Tool Palette (Available Component Field Types):**
  - Text Input, Number Field, Dropdown Select, Radio Group, Checkbox, Date Picker, Time Picker, Textarea.
  - Advanced Elements: File Uploader, Multi-Image Camera Capture, Geotagged Map Pin, Digital Signature Pad.
- **Center Canvas (Form Layout Designer):**
  - Drag-and-drop canvas layout supporting multi-column rows.
  - Reorder, duplicate, or delete field items.
- **Right Property Inspector Pane:**
  - Field ID / Code (`applicant_aadhaar`).
  - Label English & Label Tamil (`ஆதார் எண்`).
  - Placeholder & Help Text.
  - Validation Rules: Mandatory Toggle (`Required`), Min Length, Max Length, Regex Pattern (e.g., Aadhaar 12-digit pattern).
  - Conditional Visibility Rule Configurator: `Show Field B ONLY IF Field A == "Yes"`.

---

## 2. Dynamic Form Runtime Renderer Component (`/forms/render`)

### Purpose
Universal dynamic component that parses JSON form schemas (`FormTemplate` + `FormField`) and renders responsive, localized Flutter UI forms.

### UI Layout & Components
- **Dynamic Field Component Mapping:**
  - Auto-compiles schema fields into native Flutter widgets (`TextFormField`, `DropdownButtonFormField`, `DatePickerTile`, `CameraPickerTile`).
- **Real-Time Client-Side Validation Engine:**
  - Performs live regex validation, character count checks, and mandatory field highlighting.
- **Conditional Visibility Evaluator:**
  - Dynamically shows/hides dependent fields in real time based on user input.
- **Form Submission Action Bar:**
  - Draft Save Button ("Save as Draft"), Clear Form Button, Final Submit Button.
