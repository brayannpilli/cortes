# Cortes

**Link fijo: https://brayannpilli.github.io/cortes**

Esta página solo redirige al link vigente de la app (`link.json`), que el PC que la publica actualiza solo.
El código de la app no está aquí.

## Publicarla desde otro PC (Windows)

Si el PC de siempre está apagado, en cualquier otro PC con Windows:

1. Abre PowerShell (tecla Windows → escribe `powershell` → Enter).
2. Pega estas dos líneas:

   ```powershell
   irm https://brayannpilli.github.io/cortes/instalar.ps1 -OutFile "$env:TEMP\instalar-cortes.ps1"
   powershell -ExecutionPolicy Bypass -File "$env:TEMP\instalar-cortes.ps1"
   ```

3. Cuando se abra el navegador, entra en GitHub con la cuenta **brayannpilli** y autoriza.
4. Pega tu clave de Gemini cuando la pida (o Enter para seguir sin IA).
5. Doble clic en **Cortes en línea** del escritorio. El link fijo pasa a apuntar a ese PC.

La primera vez tarda unos minutos. Las siguientes, solo el paso 5.
Usa un solo PC a la vez: el último que abre «Cortes en línea» se queda con el link.
Los videos y clips se guardan en cada PC por separado.
