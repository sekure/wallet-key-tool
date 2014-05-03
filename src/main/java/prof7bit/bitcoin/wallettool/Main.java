package prof7bit.bitcoin.wallettool;

import java.io.BufferedInputStream;
import java.io.BufferedReader;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.io.InputStreamReader;
import java.util.List;

import org.spongycastle.crypto.params.KeyParameter;

import com.google.bitcoin.core.ECKey;
import com.google.bitcoin.core.NetworkParameters;
import com.google.bitcoin.core.Wallet;
import com.google.bitcoin.crypto.KeyCrypter;
import com.google.bitcoin.crypto.KeyCrypterException;
import com.google.bitcoin.store.UnreadableWalletException;

public class Main {

	public static void main(String[] args) {
		
		if (args.length != 1){
			String jarname = new java.io.File(Main.class
					.getProtectionDomain()
					.getCodeSource()
					.getLocation()
					.getPath()).getName();
			System.out.println("usage: " + jarname + " <walletfile>");
		}else{
			String filename = args[0];
			dumpWallet(filename);
		}
	}
	
	private static void dumpWallet(String filename){
		FileInputStream fileInputStream = null;
		BufferedInputStream stream = null;
		
		File walletFile = new File(filename);
		try {
			fileInputStream = new FileInputStream(walletFile);
			stream = new BufferedInputStream(fileInputStream);
			try {
				Wallet wallet = Wallet.loadFromFileStream(stream);
				stream.close();
				fileInputStream.close();
				listKeys(wallet);
			} catch (UnreadableWalletException e) {
				System.out.println("unreadable wallet file: " + filename);
				e.printStackTrace();
			}
			stream.close();
			fileInputStream.close();
		} catch (FileNotFoundException e) {
			System.out.println("file not found: " + filename);
		} catch (IOException e) {
			e.printStackTrace();
		}
	}
	
	private static void listKeys(Wallet wallet){
		NetworkParameters params = wallet.getNetworkParameters();
		KeyCrypter keyCrypter = wallet.getKeyCrypter();
		List<ECKey> list = wallet.getKeychain();
		KeyParameter aesKey = null;
		ECKey key_unenc;
		
		if (wallet.isEncrypted()){
			String pass = input("Wallet is encrypted. Enter passphrase");
			System.out.println("deriving AES key from passphrase...");
			aesKey = keyCrypter.deriveKey(pass);
		}
		
		for (ECKey key : list){
			System.out.print(key.toAddress(params));
			
			if (key.isEncrypted()){
				try {
					key_unenc = key.decrypt(keyCrypter, aesKey);
					System.out.print("   DECRYPTED ");
					System.out.print(key_unenc.getPrivateKeyEncoded(params).toString());
				} catch (KeyCrypterException e) {
					System.out.print("       ERROR ");
					System.out.print(key.getEncryptedPrivateKey().toString());
				}
			}else{
				System.out.print(" UNENCRYPTED ");
				System.out.print(key.getPrivateKeyEncoded(params).toString());
			}
			
			System.out.println();
		}
	}
	
	private static String input(String prompt){
	      BufferedReader br = new BufferedReader(new InputStreamReader(System.in));
	      String in = null;
	      System.out.print(prompt + ": ");
	      try {
	         in = br.readLine();
	      } catch (IOException ioe) {
	         System.out.println("IO error while reading interactive console input!");
	         System.exit(1);
	      }
	      return in;
	}
}