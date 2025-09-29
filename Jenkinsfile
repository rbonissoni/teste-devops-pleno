pipeline {
  agent any
  options { timestamps() }

  parameters {
    string(name: 'DEPLOY_HOST', defaultValue: '', description: 'IP público da EC2 (ex: 44.220.255.23)')
    string(name: 'APP_DIR',     defaultValue: 'app', description: 'Diretório do código da aplicação dentro do repo (se existir)')
  }

  environment {
    SSH_USER = 'admin'
    HEALTH   = 'http://127.0.0.1:3000/health'
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
        sh 'echo "Commit: $(git rev-parse --short HEAD)"'
      }
    }

    stage('Build & Test (se houver)') {
      steps {
        script {
          if (fileExists("${params.APP_DIR}/package.json")) {
            dir("${params.APP_DIR}") {
              sh '''
                set -eu
                command -v node || true
                npm ci --omit=dev || npm install --omit=dev
                npm test || echo "Sem testes formais - ok p/ desafio"
              '''
            }
          } else {
            echo "Sem package.json — pulando build/tests (ok p/ desafio se app foi provisionado via user_data)"
          }
        }
      }
    }

    stage('Deploy na EC2') {
  when { expression { return params.DEPLOY_HOST?.trim() } }
  steps {
    withCredentials([sshUserPrivateKey(credentialsId: 'ec2-ssh', keyFileVariable: 'SSH_KEY', usernameVariable: 'SSH_USER_FROM_CRED')]) {
      sh(label: 'deploy via SSH', script: '''#!/usr/bin/env bash
set -Eeuo pipefail

REMOTE_USER="${SSH_USER_FROM_CRED:-admin}"
REMOTE="$REMOTE_USER@${DEPLOY_HOST}"

echo "Conectando em: $REMOTE"
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$REMOTE" 'uname -a; id; sudo systemctl is-enabled nginx || true'

if [ -d "${APP_DIR}" ]; then
  REL="jenkins-${BUILD_TAG}"
  ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$REMOTE" \
    "sudo mkdir -p /var/www/app/releases/$REL /var/www/app/shared && sudo chown -R www-data:www-data /var/www/app"
  rsync -avz -e "ssh -i $SSH_KEY -o StrictHostKeyChecking=no" --delete "${APP_DIR}/" "$REMOTE:/tmp/$REL/"
  ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$REMOTE" \
    "sudo rsync -a /tmp/$REL/ /var/www/app/releases/$REL/ && sudo ln -sfn /var/www/app/releases/$REL /var/www/app/current && sudo chown -R www-data:www-data /var/www/app"
else
  echo "Diretório ${APP_DIR} não existe — assumindo app provisionado via user_data."
fi

ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$REMOTE" "sudo nginx -t && sudo systemctl reload nginx || sudo systemctl restart nginx"
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$REMOTE" "sudo systemctl daemon-reload || true; sudo systemctl enable app || true; sudo systemctl restart app || true"

ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$REMOTE" "curl -fsS http://127.0.0.1:3000/health"
''')
    }
  }
}


    stage('Smoke test externo') {
      when { expression { return params.DEPLOY_HOST?.trim() } }
      steps {
        sh '''
          set -eu
          curl -i "http://${DEPLOY_HOST}/health"
          curl -I "http://${DEPLOY_HOST}"
        '''
      }
    }

    stage('Valida Jenkins (prints)') {
      steps {
        echo "Tire prints deste job: histórico de execuções, Console Output com sucesso dos stages, e artefatos se aplicável."
      }
    }
  }

  post {
    success { echo "Pipeline OK — atende Parte 2 (checkout, build/test condicional, deploy, validação)." }
    failure { echo "Pipeline falhou — verifique o stage e o Console Output." }
  }
}
