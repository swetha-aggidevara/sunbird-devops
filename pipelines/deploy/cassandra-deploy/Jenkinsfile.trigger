@Library('deploy-conf') _
node() {
    try {
        String ANSI_GREEN = "\u001B[32m"
        String ANSI_NORMAL = "\u001B[0m"
        String ANSI_BOLD = "\u001B[1m"
        String ANSI_RED = "\u001B[31m"
        String ANSI_YELLOW = "\u001B[33m"

        stage('checkout public repo') {
            cleanWs()
            checkout scm
        }
            ansiColor('xterm') {
                stage('get artifact') {
                    values = lp_dp_params()
                    currentWs = sh(returnStdout: true, script: 'pwd').trim()
                    artifact = values.artifact_name + ":" + values.artifact_version
                    values.put('currentWs', currentWs)
                    values.put('artifact', artifact)
                    artifact_download(values)
                }
                stage('deploy artifact') {
                    sh """
                       unzip ${artifact}
                       mv cassandra-trigger-*.jar ansible/static-files/ 
                       """
                    ansiblePlaybook = "${currentWs}/ansible/cassandra-trigger-deploy.yml"
                    ansibleExtraArgs = "--vault-password-file /var/lib/jenkins/secrets/vault-pass -v"
                    values.put('ansiblePlaybook', ansiblePlaybook)
                    values.put('ansibleExtraArgs', ansibleExtraArgs)
                    println values
                    ansible_playbook_run(values)
                    currentBuild.result = 'SUCCESS'
                    archiveArtifacts artifacts: "${artifact}", fingerprint: true, onlyIfSuccessful: true
                    archiveArtifacts artifacts: 'metadata.json', onlyIfSuccessful: true
                    currentBuild.description = "Artifact: ${values.artifact_version}, Private: ${params.private_branch}, Public: ${params.branch_or_tag}"
                }
            }
    }
    catch (err) {
        currentBuild.result = "FAILURE"
        throw err
    }
    finally {
        slack_notify(currentBuild.result)
        email_notify()
    }
}
