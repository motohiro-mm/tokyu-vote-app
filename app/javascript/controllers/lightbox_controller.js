import { Controller } from "@hotwired/stimulus"

// 写真を押したら画面いっぱいに拡大する。拡大用の <dialog> はレイアウトに 1 つだけ置き、
// 押された写真の URL を差し替えて使い回す（写真の数だけ <dialog> を置くと一覧が重くなるため）
export default class extends Controller {
  static targets = [ "dialog", "image" ]

  // Stimulus の action params は値を JSON として読み直すため、作品名が「null」や「{"a":1}」だと別の値に化ける。
  // 参加者が入力した作品名をそのまま alt に使うため、data 属性の文字列を直接読む
  open({ currentTarget: { dataset } }) {
    this.imageTarget.src = dataset.lightboxSrc
    this.imageTarget.alt = dataset.lightboxAlt
    this.dialogTarget.showModal()
  }

  close() {
    if (!this.dialogTarget.open) return

    this.dialogTarget.close()
    // dialog の close イベントは後から届くため、画面を移動する前（turbo:before-cache）に閉じたときは
    // 写真が残ったまま Turbo のキャッシュに入る。ここでも消しておく
    this.clear()
  }

  // 次に開いたとき、前の写真が一瞬見えないよう閉じたら消しておく。Esc で閉じたときは close イベントから呼ばれる
  clear() {
    this.imageTarget.removeAttribute("src")
    this.imageTarget.alt = ""
  }
}
