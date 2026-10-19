// "/" has no content: send the visitor to the Overview page.
import { redirect } from "next/navigation";

export default function Home() {
  redirect("/overview");
}
