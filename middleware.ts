import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";

const LOCALES = ["en", "ur"];

function getLocale(pathname: string): string | null {
  const seg = pathname.split("/").filter(Boolean)[0];
  return seg && LOCALES.includes(seg) ? seg : null;
}

export async function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl;
  let response = NextResponse.next();

  // 1. Locale prefix handling
  if (pathname === "/") {
    return NextResponse.redirect(new URL("/en", request.url));
  }
  const locale = getLocale(pathname);
  if (!locale) {
    return NextResponse.redirect(new URL(`/en${pathname}`, request.url));
  }

  // 2. Refresh Supabase session on every request
  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return request.cookies.getAll();
        },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value, options }) => {
            request.cookies.set(name, value);
            response.cookies.set(name, value, options);
          });
        },
      },
    }
  );
  const {
    data: { user },
  } = await supabase.auth.getUser();

  // 3. Guard dashboard routes
  const isDashboard = pathname === `/${locale}/dashboard` || pathname.startsWith(`/${locale}/dashboard/`);
  const isLogin = pathname === `/${locale}/login`;
  if (!user && isDashboard) {
    return NextResponse.redirect(new URL(`/${locale}/login`, request.url));
  }
  if (user && isLogin) {
    return NextResponse.redirect(new URL(`/${locale}/dashboard`, request.url));
  }

  return response;
}

export const config = {
  matcher: [
    "/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)",
  ],
};
