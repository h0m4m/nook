package com.nook.app.data

import io.github.jan.supabase.auth.Auth
import io.github.jan.supabase.createSupabaseClient
import io.github.jan.supabase.postgrest.Postgrest
import io.github.jan.supabase.realtime.Realtime

val supabase = createSupabaseClient(
    supabaseUrl = "https://wzakmmuxsosfybqufdsn.supabase.co",
    supabaseKey = "sb_publishable_JG3Ur61LmZ_Uzlnb33oRxg_nazTX1LJ",
) {
    install(Auth)
    install(Postgrest)
    install(Realtime)
}
