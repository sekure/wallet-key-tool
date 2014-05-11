package prof7bit.bitcoin.wallettool

import com.google.bitcoin.core.ECKey
import com.google.bitcoin.core.Wallet
import com.google.bitcoin.crypto.KeyCrypterException
import com.google.bitcoin.crypto.KeyCrypterScrypt
import java.io.File
import org.slf4j.LoggerFactory
import org.spongycastle.crypto.params.KeyParameter

import static extension prof7bit.bitcoin.wallettool.Ext.*

/**
 * Load and save keys in MultiBit wallet format
 */
class MultibitStrategy extends ImportExportStrategy {
    val log = LoggerFactory.getLogger(this.class)

    override load(File file, String pass) {
        log.debug("loading wallet file: " + file.path)
        var KeyParameter aesKey = null
        val wallet = Wallet.loadFromFile(file)
        walletKeyTool.params = wallet.networkParameters
        if (wallet.encrypted) {
            log.debug("wallet is encrypted")
            if (pass == null){
                val pass_answered = walletKeyTool.prompt("Wallet is encrypted. Enter pass phrase")
                if (pass_answered != null && pass_answered.length > 0) {
                    aesKey = wallet.keyCrypter.deriveKey(pass_answered)
                }
            }else{
                aesKey = wallet.keyCrypter.deriveKey(pass)
            }
        }

        for (key : wallet.keychain){
            log.trace("processing {} creation time {}",
                key.toAddress(wallet.params), key.creationTimeSeconds
            )
            if (key.encrypted){
                if (aesKey != null) {
                    try {
                        walletKeyTool.add(key.decrypt(wallet.keyCrypter, aesKey))
                    } catch (KeyCrypterException e) {
                        val watch_only_key = new ECKey(null, key.pubKey)
                        watch_only_key.creationTimeSeconds = key.creationTimeSeconds
                        walletKeyTool.add(watch_only_key)
                        log.error("DECRYPT ERROR: {} {}",
                            key.toAddress(walletKeyTool.params).toString,
                            key.encryptedPrivateKey.toString
                        )
                    }
                } else {
                    val watch_only_key = new ECKey(null, key.pubKey)
                    watch_only_key.creationTimeSeconds = key.creationTimeSeconds
                    walletKeyTool.add(watch_only_key)
                    log.info("imported {} as WATCH ONLY", watch_only_key.toAddress(wallet.params))
                }
            } else {
                walletKeyTool.add(key)
            }
        }
        log.info("MultiBit wallet with {} addresses has been loaded",
            wallet.keychain.length
        )
    }

    override save(File file, String passphrase) {
        val wallet = new Wallet(walletKeyTool.params)
        log.debug("")
        for (key : walletKeyTool.keychain){
            if (key.hasPrivKey) {
                wallet.addKey(key.copy)
            } else {
                wallet.addWatchedAddress(key.toAddress(walletKeyTool.params), key.creationTimeSeconds)
                log.error("set {} as WATCH ONLY because private key is missing",
                    key.toAddress(walletKeyTool.params)
                )
            }
        }
        if (wallet.keychain.length + wallet.watchedScripts.length > 0){
            val scrypt = new KeyCrypterScrypt
            val aesKey = scrypt.deriveKey(passphrase)
            wallet.encrypt(scrypt, aesKey)
            wallet.setDescription("created by wallet-key-tool")
            wallet.setLastBlockSeenHeight(0)
            wallet.saveToFile(file)
            var msg = String.format("A new MultiBit wallet with %d addresses has been written to %s",
                wallet.keychain.length + wallet.watchedScripts.length,
                file.path
            )
            if (wallet.watchedScripts.length > 0) {
                msg = msg.concat(String.format(
                    "\n%d private keys were missing, exported them as watch-only." +
                    "\n(watch-only is currently not really supported by MultiBit," +
                    "\nit won't crash but it also probably won't be very useful.",
                    wallet.watchedScripts.length
                ))
            }
            walletKeyTool.alert(msg)
        } else {
            walletKeyTool.alert("there were no addresses or keys, wallet has not been exported")
        }
    }
}
