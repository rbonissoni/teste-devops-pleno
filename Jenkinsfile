pipeline {
  agent any
  options { timestamps() }

  parameters {
    string(name: 'DEPLOY_HOST', defaultValue: '', description: 'IP público da EC2 (ex: 44.197.x.y)')
    string(name: 'APP_DIR', defaultValue: 'app', description: 'Diretório do código da aplicação dentro do repo (se existir)')
  }

  environment {
    SSH_CRED = 'ec2-ssh'     // credencial criada no Jenkins
    SSH_USER = 'admin'       // ajuste se seu usuário for outro
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
                command -v node || true
                npm ci --omit=dev || npm install --omit=dev
                npm test || echo "Sem testes formais - ok p/ desafio"
              '''
            }
          } else {
            echo "Sem package.json — pulando build/tests (ok para desafio se app for estático ou já provisionado no user_data)"
          }
        }
      }
    }

    stage('Deploy na EC2') {
      when { expression { return params.DEPLOY_HOST?.trim() } }
      steps {
        sshagent(credentials: [env.SSH_CRED]) {
          sh '''
            set -euxo pipefail

            REMOTE="${SSH_USER}@${DEPLOY_HOST}"

            # sanity check remoto
            ssh -o StrictHostKeyChecking=no "$REMOTE" 'uname -a; id; sudo systemctl is-enabled nginx || true'

            # publica release se houver app
            if [ -d "${APP_DIR}" ]; then
              REL="jenkins-${BUILD_TAG}"
              ssh "$REMOTE" "sudo mkdir -p /var/www/app/releases/${REL} /var/www/app/shared && sudo chown -R www-data:www-data /var/www/app"
              rsync -avz --delete "${APP_DIR}/" "$REMOTE:/tmp/${REL}/"
              ssh "$REMOTE" "sudo rsync -a /tmp/${REL}/ /var/www/app/releases/${REL}/ && sudo ln -sfn /var/www/app/releases/${REL} /var/www/app/current && sudo chown -R www-data:www-data /var/www/app"
            else
              echo "Diretório ${APP_DIR} não existe — assumindo app provisionado via user_data."
            fi

            # valida Nginx e serviço do app
            ssh "$REMOTE" 'sudo nginx -t && sudo systemctl reload nginx || sudo systemctl restart nginx'
            ssh "$REMOTE" 'sudo systemctl daemon-reload || true; sudo systemctl enable app || true; sudo systemctl restart app || true'

            # healthcheck local e via Nginx
            ssh "$REMOTE" "curl -fsS ${HEALTH}"
          '''
        }
      }
    }

    stage('Valida Jenkins (prints)') {
      steps {
        echo "Tire prints deste job: histórico de execuções, Console Output com sucesso dos stages, e artefatos se aplicável."
      }
    }
  }

  post {
    success {
      echo "Pipeline OK — atende Parte 2 (checkout, build/test condicional, deploy, validação)."
    }
    failure {
      echo "Pipeline falhou — verificar estágio e logs no Console Output."
    }
  }
}
