# Cortes

**Link fijo: https://brayannpilli.github.io/cortes**

Esta página solo redirige al link vigente de la app (`link.json`), que el PC que la publica actualiza solo.
El código de la app no está aquí.

## Publicarla desde otro PC (Windows)

No hace falta cuenta de GitHub. En el otro PC:

1. Abre PowerShell (tecla Windows → escribe `powershell` → Enter).
2. Pega esta línea y escribe el **código de instalación** cuando lo pida:

   ```powershell
   irm https://brayannpilli.github.io/cortes/instalar.ps1 | iex
   ```

3. Doble clic en **Cortes en linea** del escritorio. El link fijo pasa a apuntar a ese PC.

La primera vez tarda unos minutos. Para actualizar, doble clic en **Actualizar Cortes**.
Usa un solo PC a la vez: el último que abre «Cortes en linea» se queda con el link.
Los videos y clips se guardan en cada PC por separado.

`paquete.bin` contiene la app y sus claves cifradas: solo se abre con el código de instalación.
