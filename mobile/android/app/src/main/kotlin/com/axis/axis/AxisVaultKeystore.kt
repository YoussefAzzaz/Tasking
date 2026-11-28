package com.axis.axis

import android.content.Context
import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.security.KeyStore
import java.security.SecureRandom
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * Wraps and persists the per-installation 256-bit vault encryption key and salt
 * using Android Keystore (AES/GCM) so plaintext key material is never written to disk.
 */
object AxisVaultKeystore {
    private const val ANDROID_KEYSTORE = "AndroidKeyStore"
    private const val KEY_ALIAS = "axis_credential_vault_master_v1"
    private const val PREFS_NAME = "axis_secure_vault_prefs"
    private const val PREF_ENC_KEY = "wrapped_enc_key_v1"
    private const val PREF_HASH_SALT = "wrapped_hash_salt_v1"
    private const val GCM_TAG_BITS = 128
    private const val VAULT_CHANNEL = "com.axis.axis/vault"

    fun register(flutterEngine: FlutterEngine, context: Context) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, VAULT_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getOrCreateMasterSecrets" -> {
                        try {
                            result.success(getOrCreateMasterSecrets(context))
                        } catch (e: Exception) {
                            result.error("VAULT_ERROR", e.localizedMessage, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun getOrCreateKeystoreSecretKey(): SecretKey? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return null
        val keyStore = KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }
        val existing = (keyStore.getEntry(KEY_ALIAS, null) as? KeyStore.SecretKeyEntry)?.secretKey
        if (existing != null) return existing

        val spec = KeyGenParameterSpec.Builder(
            KEY_ALIAS,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
        )
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setKeySize(256)
            .build()
        val keyGenerator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, ANDROID_KEYSTORE)
        keyGenerator.init(spec)
        return keyGenerator.generateKey()
    }

    private fun sealBytes(secretKey: SecretKey, plainBytes: ByteArray): String {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, secretKey)
        val iv = cipher.iv
        val encrypted = cipher.doFinal(plainBytes)
        return "${Base64.encodeToString(iv, Base64.NO_WRAP)}:${Base64.encodeToString(encrypted, Base64.NO_WRAP)}"
    }

    private fun unsealBytes(secretKey: SecretKey, packed: String): ByteArray? {
        val parts = packed.split(":")
        if (parts.size != 2) return null
        val iv = Base64.decode(parts[0], Base64.NO_WRAP)
        val cipherText = Base64.decode(parts[1], Base64.NO_WRAP)
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, secretKey, GCMParameterSpec(GCM_TAG_BITS, iv))
        return cipher.doFinal(cipherText)
    }

    fun getOrCreateMasterSecrets(context: Context): Map<String, String>? {
        val keyStoreKey = getOrCreateKeystoreSecretKey() ?: return null
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val rng = SecureRandom()

        fun resolveSecret(prefKey: String): String {
            val wrapped = prefs.getString(prefKey, null)
            if (!wrapped.isNullOrBlank()) {
                val restored = runCatching { unsealBytes(keyStoreKey, wrapped) }.getOrNull()
                if (restored != null && restored.size == 32) {
                    return Base64.encodeToString(restored, Base64.NO_WRAP)
                }
            }
            val fresh = ByteArray(32).also { rng.nextBytes(it) }
            val sealed = sealBytes(keyStoreKey, fresh)
            prefs.edit().putString(prefKey, sealed).apply()
            return Base64.encodeToString(fresh, Base64.NO_WRAP)
        }

        return mapOf(
            "encKeyB64" to resolveSecret(PREF_ENC_KEY),
            "hashSaltB64" to resolveSecret(PREF_HASH_SALT),
        )
    }
}
