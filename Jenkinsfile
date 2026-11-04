pipeline {
    agent any

    environment {
        APP_PORT = '8000'
    }

    stages {
        stage('Build') {
            steps {
                echo '=== STAGE 1: BUILD & ENVIRONMENT SETUP ==='
                sh '''
                    python3 -m venv .venv || true
                    . .venv/bin/activate
                    pip install -r requirements.txt
                '''
            }
        }

        stage('Deploy') {
            steps {
                echo '=== STAGE 2: AUTOMATED DEPLOYMENT ==='
                sh '''
                    chmod +x deploy.sh
                    bash deploy.sh
                '''
            }
        }

        stage('Test') {
            steps {
                echo '=== STAGE 3: LIVE TEST EXECUTION ==='
                sh '''
                    . .venv/bin/activate
                    pytest test_app.py -v -p no:warnings --junitxml=test-results.xml
                '''
            }
        }
    }

    post {
        always {
            junit allowEmptyResults: true, testResults: 'test-results.xml'
        }
        success {
            echo '====================================================='
            echo ' PIPELINE SUCCEEDED: Chatbot deployed to port 8000   '
            echo ' Live Health URL: http://localhost:8000/health       '
            echo '====================================================='
        }
        failure {
            echo '====================================================='
            echo ' PIPELINE FAILED: Inspecting application logs        '
            echo '====================================================='
            sh 'tail -n 25 app.log || true'
        }
    }
}
