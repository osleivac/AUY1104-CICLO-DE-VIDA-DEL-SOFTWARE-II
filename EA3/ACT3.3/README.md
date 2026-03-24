# Diseño y Selección de Mecanismos de Remediación Automatizada

**Objetivo:** Integrar lógica condicional y mecanismos de recuperación en los flujos de CI/CD (GitHub Actions) para manejar los escenarios de fallo identificados previamente, automatizando el *Rollback*, estandarizando el *Hotfix* y gestionando *Feature Toggles*.

Esta actividad conecta la identificación de errores (ACT 3.1) con la ejecución técnica (ACT 3.2), transformando los comandos manuales en lógica de automatización.

---

## 1. 🛡️ Estrategia de "Shift-Left": Remediación Temprana

**Concepto:** Antes de llegar al despliegue, debemos asegurar que el código defectuoso sea rechazado. Esto previene la necesidad de un rollback costoso.

### Ejercicio 1: Validaciones de Integridad (Pre-Build)

Modifica tu archivo YAML (`build-and-test.yaml`) para incluir un "Job de Bloqueo". Si este job falla, el pipeline se detiene y no se intenta construir la imagen Docker. Para esto, deberas modificar en tu package.json la versión de ```lodash``` por la ```4.17.15```.

**Modificación en el YAML:**

```yaml
jobs:
  validate-code:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Linting Check
        run: |
          npm install eslint
          npm run lint # Si esto falla, el pipeline se detiene aquí.
      
  security-audit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: NPM Audit
        # Falla si encuentra vulnerabilidades críticas
        run: npm audit --audit-level=critical
```

## 2. 🔄 Automatización del Rollback en Kubernetes
Concepto: En lugar de ejecutar kubectl rollout undo manualmente cuando algo falla, configuramos GitHub Actions para que detecte fallos en el despliegue (como un Timeout o CrashLoopBackOff) y ejecute el rollback automáticamente.

Ejercicio 2: Lógica de "Self-Healing" (Autorecuperación)
Edita el paso de despliegue en tu archivo YAML (cd-pipeline.yaml). Utilizaremos la lógica if: failure() de GitHub Actions para ejecutar pasos solo cuando el paso anterior ha fallado.

Código a implementar:
```yaml
- name: Deploy to EKS
      id: deploy-step
      run: |
        kubectl apply -f k8s/deployment.yaml
        # Esperamos a que el rollout termine exitosamente. Si tarda más de 60s, falla.
        kubectl rollout status deployment/duoc-app --timeout=60s

    - name: 🚨 Automated Rollback
      # Se ejecuta SOLO si el paso anterior (deploy-step) falló
      if: failure() 
      run: |
        echo "⚠️ Despliegue fallido detectado (Timeout/Error). Iniciando Rollback automático..."
        kubectl rollout undo deployment/duoc-app
        # Verificamos que el rollback haya sido exitoso
        kubectl rollout status deployment/duoc-app --timeout=60s
        echo "✅ Rollback completado. El sistema ha vuelto a la versión estable anterior."
```

## 3. 🚑 Pipeline de Hotfix (Parche Rápido)

Concepto: A veces, el error se descubre en producción y no se puede esperar al ciclo completo de pruebas exhaustivas. Se crea un "carril rápido" para arreglos críticos.

Ejercicio 3: Configuración de Rama Hotfix
Diseña un disparador (trigger) específico para ramas que comiencen con hotfix/. La estrategia es saltar pruebas largas de integración y desplegar inmediatamente.

Modificación en el Header del YAML:
```yaml
name: Hotfix Production Deploy
on:
  push:
    branches:
      - 'hotfix/**' # Ej: hotfix/v1.0.1-login-fix

jobs:
  fast-deploy:
    runs-on: ubuntu-latest
    steps:
      # ... (Pasos previos de Checkout y Login AWS) ...
      
      - name: Build & Push Hotfix Image
        run: |
          # Usamos el SHA del commit como tag único para rastreabilidad rápida
          docker build -t $ECR_REGISTRY/$ECR_REPOSITORY:hotfix-${{ github.sha }} .
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:hotfix-${{ github.sha }}
      
      - name: Patch Deployment Immediately
        run: |
          # Actualizamos la imagen directamente en el deployment
          kubectl set image deployment/duoc-app duoc-app-container=$ECR_REGISTRY/$ECR_REPOSITORY:hotfix-${{ github.sha }}
          kubectl rollout status deployment/duoc-app
```

## 4. 🎛️ Feature Toggles con ConfigMaps

Concepto: Para evitar tener que hacer rollback de código (re-deploy de imagen) por una funcionalidad nueva que no funciona como se espera, usamos "Feature Toggles". Desplegamos el código, pero apagamos la funcionalidad vía configuración.

Ejercicio 4: Gestión de Features sin Redespliegue de Imagen
No modificaremos el código de la aplicación (Java/Node/Python), solo la configuración de Kubernetes.

### 1. Crear/Modificar k8s/configmap.yaml:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  # Cambiar a "true" para activar, "false" para remediar un error.
  FEATURE_X_ENABLED: "false"  
  UI_COLOR: "blue"
```

### 2. Referenciar en el deployment.yaml:
```yaml
env:
    - name: FEATURE_X_ENABLED
    valueFrom:
        configMapKeyRef:
        name: app-config
        key: FEATURE_X_ENABLED
```

### Simulación de Remediación:

Escenario: Activas FEATURE_X_ENABLED: "true". Los usuarios reportan errores.

Remediación: En lugar de revertir la imagen Docker (que tarda minutos), simplemente cambias el valor a "false" en el archivo configmap.yaml y aplicas:
```yaml
kubectl apply -f k8s/configmap.yaml
kubectl rollout restart deployment/duoc-app 
# El reinicio es rápido y toma la nueva configuración desactivada.
```

## 5. 📝 Documentación de Soporte y Post-Mortem

Concepto: Para alinearse con prácticas ágiles y DevOps, cada incidente remediado debe documentarse para evitar recurrencia.

Entregable Final: Informe de Incidente (Template)
Completa la siguiente tabla basada en una de las pruebas de error (Rollback o Hotfix) que acabas de automatizar:

| Métrica | Detalle |
| :--- | :--- |
| **Incidente** | (Ej: Fallo de arranque en V2.0 debido a variable de entorno faltante) |
| **Detección** | (Ej: GitHub Action falló en el paso `rollout status` tras 60 segundos) |
| **Tiempo de Recuperación (MTTR)** | $T_{recovery} = T_{finish} - T_{failure}$ <br> (Ej: 45 segundos gracias al rollback automático) |
| **Acción de Remediación** | (Ej: Rollback automático ejecutado por script CI/CD) |
| **Prevención Futura** | (Ej: Agregar test unitario que verifique el inicio del servicio antes de construir la imagen) |