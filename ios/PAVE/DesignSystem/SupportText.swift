import PAVECore
import SwiftUI

enum SupportText {
    /// A sentence that ends with the support address as a link, like on the web.
    static func sentence(_ prefix: String, suffix: String = ".") -> AttributedString {
        var result = AttributedString(prefix)
        var link = AttributedString(PaveSupport.email)
        link.link = URL(string: "mailto:\(PaveSupport.email)")
        link.underlineStyle = .single
        link.foregroundColor = .brandGreen
        result.append(link)
        result.append(AttributedString(suffix))
        return result
    }
}
