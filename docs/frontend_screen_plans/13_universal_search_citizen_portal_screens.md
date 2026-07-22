# Screen Plan 13: Universal Search & Citizen Engagement

> **Backend Phase:** Phase 9 (Universal Search & Citizen Portal)  
> **Target Audience:** Citizens, All Municipal Employees, General Public

---

## 1. Universal Search Overlay Component (`Ctrl + K` / Global Search Bar)

### Purpose
High-performance PostgreSQL full-text search overlay allowing users to instantly find records across assets, complaints, tenders, work orders, and documents.

### UI Layout & Components
- **Global Search Input Field:**
  - Auto-focusing search bar triggered via `Ctrl + K` or header icon.
  - Multi-category search tabs: `All Results`, `Complaints`, `Assets`, `Contractors`, `Work Orders`, `Documents`.
- **Live Search Results List:**
  - Real-time instant results grouped by entity type with relevant status badges, location tags, and direct navigation links.
  - Highlights matching query keywords.

---

## 2. Citizen Self-Service Portal Home Screen (`/citizen/portal`)

### Purpose
Public portal for citizens to track filed grievances, view active local public projects, and read municipal announcements.

### UI Layout & Components
- **Welcome & Identity Header:** Citizen Name, Mobile Number, Primary Ward & Panchayat/Municipality info.
- **My Grievances Progress Widget:**
  - Cards for active filed complaints with visual step progress bar (`Filed` $\rightarrow$ `Assigned` $\rightarrow$ `Work Started` $\rightarrow$ `Resolved`).
  - Star Rating Feedback Widget for rating completed resolutions.
- **Local Civic Announcements Feed (`Announcement`):**
  - Card feed displaying official public notices (e.g., Scheduled Water Shutoff, Vaccination Drives, Gram Sabha Meetings) with Tamil text-to-speech audio reader button.
- **Civic Feedback & Survey Polls (`CitizenFeedback`):**
  - Interactive survey forms for citizen input on local development priorities.
