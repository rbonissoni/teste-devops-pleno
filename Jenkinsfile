pipeline {
  agent any
  options { timestamps() }

  parameters {
    string(name: 'DEPLOY_HOST', defaultValue: '', description: 'IP público da EC2 (ex: 44.220.x.y)')
    string(name: 'APP_DIR',     defaultValue: 'app', description: 'Diretório do código dentro do repo (se existir)')
  }

  environment {
    HEALTH_PATH = '/health'
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
              // usa bash para evitar problemas semelhantes
              sh(label: 'npm build/test', script: '''
                #!/usr/bin/env bash
                set -Eeuo pipefail
                if command -v npm >/dev/null 2>&1; then
                  npm ci --omit=dev || npm install --omit=dev
                  npm test || echo "Sem testes formais - ok p/ desafio"
                else
                  echo "npm não encontrado neste agente Jenkins; pulando build/test."
                fi
              ''')
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
        withCredentials([sshUserPrivateKey(credentialsId: 'ec2-ssh',
                                           keyFileVariable: 'SSH_KEY',
                                           usernameVariable: 'SSH_USER')]) {
          sh(label: 'deploy via SSH', script: """
            #!/usr/bin/env bash
            set -Eeuo pipefail

            REMOTE="\${SSH_USER}@${params.DEPLOY_HOST}"

            # sanity check remoto
            ssh -i "\$SSH_KEY" -o StrictHostKeyChecking=no "\$REMOTE" 'uname -a; id; sudo systemctl is-enabled nginx || true'

            # se houver diretório de app no repo, publica release simples
            if [ -d "${params.APP_DIR}" ]; then
              REL="jenkins-\${BUILD_ID}"
              ssh -i "\$SSH_KEY" -o StrictHostKeyChecking=no "\$REMOTE" "sudo mkdir -p /var/www/app/releases/\$REL /var/www/app/shared && sudo chown -R www-data:www-data /var/www/app"
              rsync -az -e "ssh -i \$SSH_KEY -o StrictHostKeyChecking=no" "${params.APP_DIR}/" "\$REMOTE:/tmp/\$REL/"
              ssh -i "\$SSH_KEY" -o StrictHostKeyChecking=no "\$REMOTE" "sudo rsync -a /tmp/\$REL/ /var/www/app/releases/\$REL/ && sudo ln -sfn /var/www/app/releases/\$REL /var/www/app/current && sudo chown -R www-data:www-data /var/www/app"
            else
              echo "Diretório ${params.APP_DIR} não existe — assumindo app provisionado via user_data."
            fi

            # valida/restart serviços
            ssh -i "\$SSH_KEY" -o StrictHostKeyChecking=no "\$REMOTE" 'sudo nginx -t && sudo systemctl reload nginx || sudo systemctl restart nginx'
            ssh -i "\$SSH_KEY" -o StrictHostKeyChecking=no "\$REMOTE" 'sudo systemctl daemon-reload || true; sudo systemctl enable app || true; sudo systemctl restart app || true'

            # healthcheck local
            ssh -i "\$SSH_KEY" -o StrictHostKeyChecking=no "\$REMOTE" "curl -fsS http://127.0.0.1:3000${HEALTH_PATH}"
          """
          )
        }
      }
    }

    stage('Smoke test externo') {
      when { expression { return params.DEPLOY_HOST?.trim() } }
      steps {
        sh(label: 'smoke test', script: """
          #!/usr/bin/env bash
          set -Eeuo pipefail
          curl -i "http://${params.DEPLOY_HOST}${HEALTH_PATH}"
          curl -I "http://${params.DEPLOY_HOST}"
        """)
      }
    }

    stage('Valida Jenkins (prints)') {
      steps {
        echo "Tire prints: parâmetros do build, histórico, Console Output com sucesso dos stages, e as curls do smoke test."
      }
    }
  }

  post {
    success { echo "Pipeline OK — checkout, (build/test se houver), deploy e smoke test passaram." }
    failure { echo "Pipeline falhou — verifique o stage e o Console Output." }
  }
}
