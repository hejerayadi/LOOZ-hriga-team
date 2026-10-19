// Shapes of the data sent by the backend (same as backend/app/schemas.py).

export type Role = "farmer" | "expert" | "admin";

export type Profile = {
  id: string;
  role: Role;
  name: string;
  email: string | null;
  phone: string | null;
  language: string | null;
  zone: string | null;
  farm_name: string | null;
  speciality: string | null;
  verified: boolean | null;
  created_at: string | null;
};
