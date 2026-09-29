// Supabase > Project Settings > API
const SUPABASE_URL = "https://kvgsbctdedqitqpsculp.supabase.co";
const SUPABASE_ANON_KEY = "sb_publishable_nokoK2OTwVMsXz1eVW3Y9A_0ibuG_F5";
const SB = supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
const esc = s => String(s ?? "").replace(/[&<>"']/g, c => ({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
const UPI_ID = "yourname@upi"; // shop UPI ID that receives payments
