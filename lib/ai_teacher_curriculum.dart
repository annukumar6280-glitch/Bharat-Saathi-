class AiTeacherCurriculum {
  // 4 courses x 6 parts x 5 lessons = 120 guided lessons.
  static const courseParts = <String, List<({String title, List<String> lessons})>>{
    'English Skills': [
      (title: 'Level 1 • English Foundations', lessons: ['Alphabet and pronunciation', 'Basic words and meanings', 'Pronouns and naming words', 'Be verbs: am, is, are', 'Simple everyday sentences']),
      (title: 'Level 2 • Grammar and Sentence Building', lessons: ['Nouns and articles', 'Pronouns and possessives', 'Adjectives and adverbs', 'Prepositions and conjunctions', 'Positive, negative and question forms']),
      (title: 'Level 3 • Tenses and Conversation', lessons: ['Simple present tense', 'Present continuous tense', 'Simple past tense', 'Future forms', 'Daily conversation and polite expressions']),
      (title: 'Level 4 • Reading and Writing', lessons: ['Reading short passages', 'Understanding paragraphs', 'Writing clear sentences', 'Paragraph and story writing', 'Messages, letters and emails']),
      (title: 'Level 5 • Practical and Workplace English', lessons: ['Self introduction and interviews', 'Telephone and customer conversations', 'Workplace instructions and meetings', 'Forms, applications and official letters', 'Travel, shopping and public services']),
      (title: 'Level 6 • Advanced Communication', lessons: ['Advanced vocabulary and collocations', 'Complex sentences and clauses', 'Reported speech and passive voice', 'Presentations, discussions and debates', 'Fluency, pronunciation and error correction']),
    ],
    'Computer & Digital Skills': [
      (title: 'Level 1 • Computer Foundations', lessons: ['What is a computer and how it works', 'Hardware and software', 'Parts of a computer', 'Keyboard, mouse and shortcuts', 'Starting, shutting down and basic settings']),
      (title: 'Level 2 • Operating Systems and File Management', lessons: ['Desktop, windows and settings', 'Files, folders and file extensions', 'Copy, move, rename and delete files', 'Storage devices and backups', 'Installing and updating applications safely']),
      (title: 'Level 3 • Office and Productivity Tools', lessons: ['Word processing and document formatting', 'Tables, page layout and printing', 'Spreadsheet rows, columns and cells', 'Formulas, functions, sorting and charts', 'Presentations and slide design']),
      (title: 'Level 4 • Internet and Digital Services', lessons: ['Internet, browsers and search engines', 'Email and attachments', 'Cloud storage and online collaboration', 'Video meetings and digital communication', 'Online forms, bookings and government services']),
      (title: 'Level 5 • Cyber Safety and Digital Payments', lessons: ['Strong passwords and two-step verification', 'Recognising scams, phishing and fake links', 'Privacy, permissions and safe downloads', 'UPI, QR payments and transaction checks', 'Safe banking, recovery and reporting fraud']),
      (title: 'Level 6 • Advanced Digital Skills', lessons: ['Introduction to coding and algorithms', 'HTML, CSS and how websites work', 'Data, databases and spreadsheets at work', 'AI tools and responsible AI use', 'Troubleshooting, networks and device maintenance']),
    ],
    'Maths & General Knowledge': [
      (title: 'Level 1 • Number Foundations', lessons: ['Numbers, place value and number lines', 'Addition with carrying', 'Subtraction with borrowing', 'Multiplication tables and methods', 'Division and remainders']),
      (title: 'Level 2 • Fractions, Decimals and Percentages', lessons: ['Fractions and equivalent fractions', 'Adding and subtracting fractions', 'Decimals and conversions', 'Percentages and percentage change', 'Ratio, proportion and unitary method']),
      (title: 'Level 3 • Everyday and Commercial Maths', lessons: ['Money, bills and change', 'Discount, markup and sale price', 'Profit, loss and commission', 'Simple interest and savings', 'GST basics and invoice calculations']),
      (title: 'Level 4 • Algebra and Geometry', lessons: ['Variables and algebraic expressions', 'Simple equations and inequalities', 'Powers, roots and order of operations', 'Lines, angles and triangles', 'Perimeter, area, volume and measurement']),
      (title: 'Level 5 • Data and Applied Mathematics', lessons: ['Tables, graphs and data reading', 'Mean, median, mode and range', 'Probability basics', 'Time, speed and distance', 'Multi-step word problems and estimation']),
      (title: 'Level 6 • Science and General Knowledge', lessons: ['Human body, health and nutrition basics', 'Matter, force, energy and simple machines', 'Plants, animals and ecosystems', 'Earth, weather, climate and space', 'India, civics, history and world geography']),
    ],
    'Business Skills': [
      (title: 'Level 1 • Business Foundations', lessons: ['What is a business and how it creates value', 'Types of businesses and ownership', 'Finding customer needs and solving problems', 'Choosing products and services', 'Basic business ethics and record keeping']),
      (title: 'Level 2 • Planning and Starting a Business', lessons: ['Market research and competitor study', 'Business model and value proposition', 'Business plan and goals', 'Startup costs, capital and resources', 'Licences, compliance and professional advice']),
      (title: 'Level 3 • Marketing, Branding and Digital Presence', lessons: ['Brand name, positioning and customer trust', 'Pricing strategy and product presentation', 'Local marketing and referrals', 'Social media and digital marketing basics', 'Offers, campaigns and measuring results']),
      (title: 'Level 4 • Sales and Customer Relationships', lessons: ['Understanding customer behaviour', 'Asking questions and explaining benefits', 'Sales conversation and negotiation', 'Handling objections and complaints', 'Repeat customers, service and feedback']),
      (title: 'Level 5 • Daily Operations and Team Management', lessons: ['Purchasing, suppliers and stock control', 'Inventory records and reorder planning', 'Daily operations and quality checks', 'Time management and staff responsibilities', 'Customer orders, delivery and returns']),
      (title: 'Level 6 • Accounts, Finance and Growth', lessons: ['Recording income, expenses and cash flow', 'Costing, gross profit and net profit', 'Break-even point and business budgeting', 'Digital payments, invoices and tax awareness', 'Business performance, risk and responsible growth']),
    ],
  };
}
