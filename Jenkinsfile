pipeline {
    agent any

    parameters {
        booleanParam(
            name: 'FAIL_DEMO',
            defaultValue: false,
            description: 'Run a deliberately failing test to prove the CI gate blocks deployment.'
        )
        booleanParam(
            name: 'RUN_VAULT_DEMO',
            defaultValue: false,
            description: 'Fetch the chatbot secret from Vault to demonstrate masked credential handling.'
        )
    }

    environment {
        APP_PORT = '8010'
        FAIL_DEMO = "${params.FAIL_DEMO}"
    }

    stages {
        stage('Install Dependencies') {
            steps {
                echo '=== STAGE 1: INSTALL ==='
                sh '''
                    python3 -m venv .venv
                    . .venv/bin/activate
                    pip install --upgrade pip
                    pip install -r requirements.txt
                '''
            }
        }

        stage('Unit Tests') {
            steps {
                echo '=== STAGE 2: UNIT TEST GATE ==='
                sh '''
                    . .venv/bin/activate
                    python -m pytest tests/test_unit.py -v -p no:warnings \
                        --junitxml=unit-results.xml
                '''
            }
        }

        stage('Integration Tests') {
            steps {
                echo '=== STAGE 3: INTEGRATION TEST GATE ==='
                sh '''
                    . .venv/bin/activate
                    uvicorn app:app --host 127.0.0.1 --port 8010 \
                        > integration.log 2>&1 &
                    SERVER_PID=$!
                    trap "kill $SERVER_PID 2>/dev/null || true" EXIT

                    for i in $(seq 1 30); do
                        if curl -sf http://127.0.0.1:8010/health >/dev/null; then
                            break
                        fi
                        sleep 1
                    done

                    APP_URL=http://127.0.0.1:8010 \
                        python -m pytest tests/test_integration.py -v -p no:warnings \
                        --junitxml=integration-results.xml
                '''
            }
        }

        stage('Security Scan (SAST)') {
            steps {
                echo '=== STAGE 4: BANDIT SAST GATE ==='
                sh '''
                    . .venv/bin/activate
                    bandit -r app.py -ll
                '''
            }
        }

        stage('Vault Secret Check') {
            when {
                expression { params.RUN_VAULT_DEMO }
            }
            steps {
                echo '=== STAGE 5: MASKED SECRET HANDLING ==='
                withCredentials([string(credentialsId: 'vault-token', variable: 'VAULT_TOKEN')]) {
                    sh '''
                        . .venv/bin/activate
                        python - <<'PY'
import json
import os
import urllib.request

token = os.environ["VAULT_TOKEN"]
request = urllib.request.Request(
    "http://127.0.0.1:8201/v1/secret/data/chatbot",
    headers={"X-Vault-Token": token},
)
with urllib.request.urlopen(request, timeout=5) as response:
    payload = json.load(response)["data"]["data"]

key = payload.get("GEMINI_API_KEY", "")
print(f"Vault reachable: yes")
print(f"GEMINI_API_KEY present: {bool(key)}")
print(f"GEMINI_API_KEY length: {len(key)}")
print("The value was never printed or written to the repository.")
PY
                    '''
                }
            }
        }
    }

    post {
        always {
            junit allowEmptyResults: true, testResults: 'unit-results.xml, integration-results.xml'
        }
        success {
            echo '====================================================='
            echo ' CI PASSED: tests are green; the change is safe to deploy '
            echo ' Argo CD will deliver it from Git                        '
            echo '====================================================='
        }
        failure {
            echo '====================================================='
            echo ' CI FAILED: deployment gate blocked                     '
            echo '====================================================='
            sh 'tail -n 25 integration.log || true'
        }
    }
}
